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

-export([load/1, unload/1]).

-export([on_client_connected/4,
         on_client_disconnected/3
        ]).

-export([on_client_subscribe/3,
         on_client_unsubscribe/3
        ]).

-export([on_message_publish/2,
         on_message_delivered/3,
         on_message_acked/3
        ]).

-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

-define(RUNTIME, ?MODULE).

%%------------------------------------------------------------------------------
%% Start
%%------------------------------------------------------------------------------

%% Called when the plugin application start
load(Env) ->
    emqx:hook('client.connected', fun ?MODULE:on_client_connected/4, [Env]),
    emqx:hook('client.disconnected', fun ?MODULE:on_client_disconnected/3, [Env]),
    emqx:hook('client.subscribe', fun ?MODULE:on_client_subscribe/3, [Env]),
    emqx:hook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3, [Env]),
    emqx:hook('message.publish', fun ?MODULE:on_message_publish/2, [Env]),
    emqx:hook('message.delivered', fun ?MODULE:on_message_delivered/3, [Env]),
    emqx:hook('message.acked', fun ?MODULE:on_message_acked/3, [Env]).

%%------------------------------------------------------------------------------
%% Callbacks
%%------------------------------------------------------------------------------

on_client_connected(#{client_id := ClientId}, ConnAck, ConnAttrs, _Env) ->
    ?LOG(info, "[RuleEngine] Client(~s) connected, connack: ~w, conn_attrs:~p",
         [ClientId, ConnAck, ConnAttrs]).

on_client_disconnected(#{client_id := ClientId}, ReasonCode, _Env) ->
    ?LOG(info, "[RuleEngine] Client(~s) disconnected, reason_code: ~w",
         [ClientId, ReasonCode]).

on_client_subscribe(#{client_id := ClientId}, RawTopicFilters, _Env) ->
    ?LOG(info, "[RuleEngine] Client(~s) will subscribe: ~p",
         [ClientId, RawTopicFilters]),
    {ok, RawTopicFilters}.

on_client_unsubscribe(#{client_id := ClientId}, RawTopicFilters, _Env) ->
    ?LOG(info, "[RuleEngine] Client(~s) unsubscribe ~p",
         [ClientId, RawTopicFilters]),
    {ok, RawTopicFilters}.

on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>},
                   #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_publish(Message, _Env) ->
    ?LOG(info, "[RuleEngine] Publish ~s", [emqx_message:format(Message)]),
    Rules = emqx_rule_registry:get_rules_for('message.publish'),
    ok = execute(Rules, #{message => Message}),
    {ok, Message}.

on_message_delivered(#{client_id := ClientId}, Message, _Env) ->
    ?LOG(info, "[RuleEngine] Delivered message to client(~s): ~s",
         [ClientId, emqx_message:format(Message)]),
    {ok, Message}.

on_message_acked(#{client_id := ClientId}, Message, _Env) ->
    ?LOG(info, "[RuleEngine] Session(~s) acked message: ~s",
         [ClientId, emqx_message:format(Message)]),
    {ok, Message}.

%%------------------------------------------------------------------------------
%% Execute rules
%%------------------------------------------------------------------------------

-spec(execute(list(emqx_rule_engine:rule()), term()) -> ok).
execute([], _Input) ->
    ok;

execute([#rule{conditions = Conditions, actions = Actions}|Rules], Input) ->
    case match(Conditions, Input) of
        true ->
            lists:foreach(fun(Action) -> Action(Input) end, Actions);
        false -> ok
    end,
    execute(Rules, Input).

match(_Conditions, _Input) ->
    true.

%%------------------------------------------------------------------------------
%% Stop
%%------------------------------------------------------------------------------

%% Called when the rule engine application stop
unload(_Env) ->
    emqx:unhook('client.connected', fun ?MODULE:on_client_connected/4),
    emqx:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
    emqx:unhook('client.subscribe', fun ?MODULE:on_client_subscribe/3),
    emqx:unhook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3),
    emqx:unhook('message.publish', fun ?MODULE:on_message_publish/2),
    emqx:unhook('message.delivered', fun ?MODULE:on_message_delivered/3),
    emqx:unhook('message.acked', fun ?MODULE:on_message_acked/3).

%%------------------------------------------------------------------------------
%% Start the runtime server
%%------------------------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?RUNTIME}, ?MODULE, [], []).

%%------------------------------------------------------------------------------
%% gen_server callbacks
%%------------------------------------------------------------------------------

init([]) ->
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


