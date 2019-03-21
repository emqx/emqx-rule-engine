%% Copyright (c) 2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(emqx_rule_runtime).

-include("rule_engine.hrl").
-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").

-export([start/1, stop/1]).

-export([ on_client_connected/4
        , on_client_disconnected/3
        , on_client_subscribe/3
        , on_client_unsubscribe/3
        , on_session_created/3
        , on_session_terminated/3
        , on_session_subscribed/4
        , on_session_unsubscribed/4
        , on_session_resumed/3
        , on_message_publish/2
        , on_message_deliver/3
        , on_message_acked/3
        ]).

%%------------------------------------------------------------------------------
%% Start
%%------------------------------------------------------------------------------

start(Env) ->
    hook_rules('client.connected', fun ?MODULE:on_client_connected/4, Env),
    hook_rules('client.disconnected', fun ?MODULE:on_client_disconnected/3, Env),
    hook_rules('client.subscribe', fun ?MODULE:on_client_subscribe/3, Env),
    hook_rules('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3, Env),
    hook_rules('session.created', fun ?MODULE:on_session_created/3, Env),
    hook_rules('session.resumed', fun ?MODULE:on_session_resumed/3, Env),
    hook_rules('session.terminated', fun ?MODULE:on_session_terminated/3, Env),
    hook_rules('session.subscribed', fun ?MODULE:on_session_subscribed/4, Env),
    hook_rules('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4, Env),
    hook_rules('message.publish', fun ?MODULE:on_message_publish/2, Env),
    hook_rules('message.deliver', fun ?MODULE:on_message_deliver/3, Env),
    hook_rules('message.acked', fun ?MODULE:on_message_acked/3, Env).

hook_rules(Name, Fun, Env) ->
    emqx:hook(Name, Fun, [Env#{apply_fun => apply_rules_fun(Name)}]).

%%------------------------------------------------------------------------------
%% Callbacks
%%------------------------------------------------------------------------------

on_client_connected(Credentials = #{client_id := ClientId}, ConnAck, ConnAttrs, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Client(~s) connected, connack: ~w, conn_attrs:~p",
         [ClientId, ConnAck, ConnAttrs]),
    ApplyRules(maps:merge(Credentials, #{connack => ConnAck, connattrs => ConnAttrs})).

on_client_disconnected(Credentials = #{client_id := ClientId}, ReasonCode, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Client(~s) disconnected, reason_code: ~w",
         [ClientId, ReasonCode]),
    ApplyRules(maps:merge(Credentials, #{reason_code => ReasonCode})).

on_client_subscribe(#{client_id := ClientId}, TopicFilters, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Client(~s) will subscribe: ~p",
         [ClientId, TopicFilters]),
    ApplyRules(#{client_id => ClientId, topic_filters => TopicFilters}),
    {ok, TopicFilters}.

on_client_unsubscribe(#{client_id := ClientId}, TopicFilters, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Client(~s) unsubscribe ~p",
         [ClientId, TopicFilters]),
    ApplyRules(#{client_id => ClientId, topic_filters => TopicFilters}),
    {ok, TopicFilters}.

on_session_created(#{client_id := ClientId}, Info, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Session(~s) created ~p",
         [ClientId, Info]),
    ApplyRules(#{client_id => ClientId, info => Info}),
    ok.

on_session_resumed(#{client_id := ClientId}, Attrs, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Session(~s) resumed ~p",
         [ClientId, Attrs]),
    ApplyRules(#{client_id => ClientId, attrs => Attrs}),
    ok.

on_session_terminated(#{client_id := ClientId, username := Username}, Reason, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Session(~s) terminated for ~p",
         [ClientId, Reason]),
    ApplyRules(#{client_id => ClientId, username => Username, reason => Reason}),
    ok.

on_session_subscribed(#{client_id := ClientId, username := Username}, Topic, SubOpts, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Session(~s) subscribed topic: ~p",
         [ClientId, Topic]),
    ApplyRules(#{client_id => ClientId, username => Username, topic => Topic, sub_opts => SubOpts}),
    ok.

on_session_unsubscribed(#{client_id := ClientId, username := Username}, Topic, SubOpts, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Session(~s) unsubscribed topic: ~p",
         [ClientId, Topic]),
    ApplyRules(#{client_id => ClientId, username => Username, topic => Topic, sub_opts => SubOpts}),
    ok.

on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>},
                   #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_publish(Message, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Publish ~s", [emqx_message:format(Message)]),
    ApplyRules(emqx_message:to_map(Message)),
    {ok, Message}.

on_message_deliver(Credentials = #{client_id := ClientId}, Message, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Delivered message to client(~s): ~s",
         [ClientId, emqx_message:format(Message)]),
    ApplyRules(maps:merge(Credentials, emqx_message:to_map(Message))),
    {ok, Message}.

on_message_acked(#{client_id := ClientId, username := Username}, Message, #{apply_fun := ApplyRules}) ->
    ?LOG(info, "[RuleEngine] Session(~s) acked message: ~s",
         [ClientId, emqx_message:format(Message)]),
    ApplyRules(maps:merge(emqx_message:to_map(Message), #{client_id => ClientId, username => Username})),
    {ok, Message}.

%%------------------------------------------------------------------------------
%% Apply rules
%%------------------------------------------------------------------------------

apply_rules_fun(Hook) ->
    fun(Input) -> apply_rules(rules_for(Hook), Input) end.

rules_for(Hook) ->
    emqx_rule_registry:get_rules_for(Hook).

-spec(apply_rules(list(emqx_rule_engine:rule()), map()) -> ok).
apply_rules([], _Input) ->
    ok;

apply_rules([Rule = #rule{name = Name}|Rules], Input) ->
    try apply_rule(Rule, Input)
    catch
        _:Error:StkTrace ->
            ?LOG(error, "Apply the rule ~s error: ~p. Statcktrace:~n~p",
                 [Name, Error, StkTrace])
    end,
    apply_rules(Rules, Input).

apply_rule(#rule{conditions = Conditions,
                 topic = TopicFilter,
                 selects = Selects,
                 actions = Actions}, Input) ->
    case match_topic(TopicFilter, Input) of
        true ->
            %%TODO: Transform ???
            Selected = select_data(Selects, Input),
            case match_conditions(Conditions, Selected) of
                true ->
                    take_actions(Actions, Selected);
                false -> ok
            end;
        false -> ok
    end.

%% 0. Match a topic filter
match_topic(undefined, _Input) ->
    true;
match_topic(Filter, #{topic := Topic}) ->
    emqx_topic:match(Topic, Filter).

%% TODO: 1. Select data from input
select_data(_Selects, Input) ->
    Input.

%% TODO: 2. Match selected data with conditions
match_conditions(_Conditions, _Data) ->
    true.

%% 3. Take actions
take_actions(Actions, Data) ->
    lists:foreach(fun(Action) -> take_action(Action, Data) end, Actions).

take_action(#{apply := Apply}, Data) ->
    Apply(Data).

%% TODO: 4. the resource?
%% call_resource(_ResId) ->
%%    ok.

%%------------------------------------------------------------------------------
%% Stop
%%------------------------------------------------------------------------------

%% Called when the rule engine application stop
stop(_Env) ->
    emqx:unhook('client.connected', fun ?MODULE:on_client_connected/4),
    emqx:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
    emqx:unhook('client.subscribe', fun ?MODULE:on_client_subscribe/3),
    emqx:unhook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3),
    emqx:unhook('session.created', fun ?MODULE:on_session_created/3),
    emqx:unhook('session.resumed', fun ?MODULE:on_session_resumed/3),
    emqx:unhook('session.terminated', fun ?MODULE:on_session_terminated/3),
    emqx:unhook('session.subscribed', fun ?MODULE:on_session_subscribed/4),
    emqx:unhook('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4),
    emqx:unhook('message.publish', fun ?MODULE:on_message_publish/2),
    emqx:unhook('message.deliver', fun ?MODULE:on_message_deliver/3),
    emqx:unhook('message.acked', fun ?MODULE:on_message_acked/3).

