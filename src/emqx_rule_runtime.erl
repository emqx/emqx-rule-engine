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
        , on_message_publish/2
        , on_message_dropped/3
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
    hook_rules('message.publish', fun ?MODULE:on_message_publish/2, Env),
    hook_rules('message.dropped', fun ?MODULE:on_message_dropped/3, Env),
    hook_rules('message.deliver', fun ?MODULE:on_message_deliver/3, Env),
    hook_rules('message.acked', fun ?MODULE:on_message_acked/3, Env).

hook_rules(Name, Fun, Env) ->
    emqx:hook(Name, Fun, [Env#{apply_fun => apply_rules_fun(bin(Name))}]).

%%------------------------------------------------------------------------------
%% Callbacks
%%------------------------------------------------------------------------------

on_client_connected(Credentials = #{client_id := ClientId}, ConnAck, ConnAttrs, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Client(~s) connected, connack: ~w, conn_attrs:~p",
         [ClientId, ConnAck, ConnAttrs]),
    ApplyRules(maps:merge(bin_key_map(Credentials), #{<<"hook">> => 'client.connected', <<"connack">> => ConnAck, <<"connattrs">> => ConnAttrs})).

on_client_disconnected(Credentials = #{client_id := ClientId}, ReasonCode, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Client(~s) disconnected, reason_code: ~w",
         [ClientId, ReasonCode]),
    ApplyRules(maps:merge(bin_key_map(Credentials), #{<<"hook">> => 'client.disconnected', <<"reason_code">> => ReasonCode})).

on_client_subscribe(#{client_id := ClientId}, TopicFilters, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Client(~s) will subscribe: ~p",
         [ClientId, TopicFilters]),
    ApplyRules(#{<<"hook">> => 'client.subscribe', <<"client_id">> => ClientId, <<"topic_filters">> => TopicFilters}),
    {ok, TopicFilters}.

on_client_unsubscribe(#{client_id := ClientId}, TopicFilters, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Client(~s) unsubscribe ~p",
         [ClientId, TopicFilters]),
    ApplyRules(#{<<"hook">> => 'client.unsubscribe', <<"client_id">> => ClientId, <<"topic_filters">> => TopicFilters}),
    {ok, TopicFilters}.

on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>},
                   #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_publish(Message, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Publish ~s", [emqx_message:format(Message)]),
    ApplyRules(maps:merge(emqx_message:to_bin_key_map(Message), #{<<"hook">> => 'message.publish'})),
    {ok, Message}.

on_message_dropped(_, Message = #message{topic = <<"$SYS/", _/binary>>},
                   #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_dropped(#{node := Node}, Message, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Message ~s dropped for no subscription", [emqx_message:format(Message)]),
    ApplyRules(maps:merge(emqx_message:to_bin_key_map(Message), #{<<"node">> => Node, <<"hook">> => 'message.dropped'})),
    {ok, Message}.

on_message_deliver(Credentials = #{client_id := ClientId}, Message, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Delivered message to client(~s): ~s",
         [ClientId, emqx_message:format(Message)]),
    ApplyRules(maps:merge(bin_key_map(Credentials#{<<"hook">> => 'message.deliver'}),
                          emqx_message:to_bin_key_map(Message))),
    {ok, Message}.

on_message_acked(#{client_id := ClientId, username := Username}, Message, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Session(~s) acked message: ~s",
         [ClientId, emqx_message:format(Message)]),
    ApplyRules(maps:merge(emqx_message:to_bin_key_map(Message), #{<<"hook">> => 'message.acked', <<"client_id">> => ClientId, <<"username">> => Username})),
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
apply_rules([Rule = #rule{name = Name}|More], Input) ->
    try apply_rule(Rule, Input)
    catch
        _:Error:StkTrace ->
            ?LOG(error, "Apply the rule ~s error: ~p. Statcktrace:~n~p",
                 [Name, Error, StkTrace])
    end,
    apply_rules(More, Input).

apply_rule(#rule{selects = Selects,
                 conditions = Conditions,
                 actions = Actions}, Input) ->
    Data = select_data(Selects, Input),
    case match_conditions(Conditions, Data) of
        true ->
            take_actions(Actions, Data);
        false -> ok
    end.

%% 1. Select data from input
select_data(Fields, Input) ->
    select_data(Fields, Input, #{}).

select_data([], _Input, Acc) ->
    Acc;
select_data([<<"*">>|More], Input, Acc) ->
    select_data(More, Input, maps:merge(Acc, Input));
select_data([<<"headers.", Name/binary>>|More], Input, Acc) ->
    Headers = get_value(<<"headers">>, Input, #{}),
    Val = get_value(Name, Headers, null),
    select_data(More, Input, maps:put(Name, Val, Acc));
select_data([<<"payload.", Attr/binary>>|More], Input, Acc) ->
    {Json, Input1} = parse_payload(Input),
    Val = get_value(Attr, Json, null),
    select_data(More, Input1, maps:put(Attr, Val, Acc));
select_data([Var|More], Input, Acc) when is_binary(Var) ->
    Val = get_value(Var, Input, null),
    select_data(More, Input, maps:put(Var, Val, Acc));
select_data([{'fun', Name, Args}|More], Input, Acc) ->
    Var = select_fun_var(Name, Args),
    Val = erlang:apply(select_fun(Name, Args), Input),
    select_data(More, Input, maps:put(Var, Val, Acc));
select_data([{as, <<"headers.", Name/binary>>, Alias}|More], Input, Acc) ->
    Headers = get_value(<<"headers">>, Input, #{}),
    Val = get_value(Name, Headers, null),
    select_data(More, Input, maps:put(Alias, Val, Acc));
select_data([{as, <<"payload.", Attr/binary>>, Alias}|More], Input, Acc) ->
    {Json, Input1} = parse_payload(Input),
    Val = get_value(Attr, Json, null),
    select_data(More, Input1, maps:put(Alias, Val, Acc));
select_data([{as, Var, Alias}|More], Input, Acc) when is_binary(Var) ->
    Val = get_value(Var, Input, null),
    select_data(More, Input, maps:put(Alias, Val, Acc));
select_data([{as, {'fun', Name, Args}, Alias}|More], Input, Acc) ->
    Val = erlang:apply(select_fun(Name, Args), Input),
    select_data(More, Input, maps:put(Alias, Val, Acc)).

select_fun(Name, Args) ->
    Fun = list_to_existing_atom(binary_to_list(Name)),
    erlang:apply(emqx_rule_funcs, Fun, Args).

select_fun_var(Name, Args) ->
    iolist_to_binary([Name, "(", binary_join(Args, <<",">>), ")"]).

parse_payload(Input) ->
    case maps:find(payload_json, Input) of
        {ok, Json} ->
            {Json, Input};
        error ->
            %% TODO: remove the default payload later
            Payload = get_value(<<"payload">>, Input, <<"{}">>),
            Json = emqx_json:decode(Payload, [return_maps]),
            {Json, maps:put(payload_json, Json, Input)}
    end.

binary_join([], _Sep) ->
    <<>>;
binary_join([Bin], _Sep) ->
    Bin;
binary_join([H|T], Sep) ->
    lists:foldl(fun(Bin, Acc) -> <<Acc/binary, Sep/binary, Bin/binary>> end, H, T).

%% 2. Match selected data with conditions
match_conditions({'and', L, R}, Data) ->
    match_conditions(L, Data) andalso match_conditions(R, Data);
match_conditions({'or', L, R}, Data) ->
    match_conditions(L, Data) orelse match_conditions(R, Data);
match_conditions({'=', <<"topic">>, Topic}, Data) ->
    match_topic_filter(get_value(<<"topic">>, Data), eval(Topic, Data));
match_conditions({'=', L, R}, Data) ->
    eval(L, Data) == eval(R, Data);
match_conditions({'>', L, R}, Data) ->
    eval(L, Data) > eval(R, Data);
match_conditions({'<', L, R}, Data) ->
    eval(L, Data) < eval(R, Data);
match_conditions({'<=', L, R}, Data) ->
    eval(L, Data) =< eval(R, Data);
match_conditions({'>=', L, R}, Data) ->
    eval(L, Data) >= eval(R, Data);
match_conditions({NotEq, L, R}, Data)
  when NotEq =:= '<>'; NotEq =:= '!=' ->
    eval(L, Data) =/= eval(R, Data);
match_conditions({'not', Var}, Data) ->
    not get_value(Var, Data, false);
match_conditions({in, Var, {list, Vals}}, Data) ->
    match_with_key(Var, fun(Val) ->
                                lists:member(Val, [eval(V, Data) || V <- Vals])
                        end, Data);
match_conditions({}, _Data) ->
    true.

%% Match topic filter
match_topic_filter(Topic, Filter) when is_binary(Topic), is_binary(Filter)->
    emqx_topic:match(Topic, Filter).

match_with_key(Key, Fun, Data) ->
    maps:is_key(Key, Data) andalso Fun(get_value(Key, Data)).

%% quoted string
eval(<<Quote:1/binary, S/binary>>, _) when Quote =:= <<$'>>; Quote =:= <<$">>->
    binary:part(S, {0, byte_size(S) - 1});
%% integer | variable
eval(V, Data) ->
    try binary_to_integer(V)
    catch
        error:badarg ->
            get_value(V, Data, V)
    end.

%% 3. Take actions
take_actions(Actions, Data) ->
    lists:foreach(fun(Action) -> take_action(Action, Data) end, Actions).

take_action(#{apply := Apply}, Data) ->
    Apply(Data).

%% TODO: 4. is the resource available?
%% call_resource(_ResId) ->
%%    ok.

get_value(Key, Data) ->
    get_value(Key, Data, undefined).

get_value(Key, Data, Default) when is_binary(Key) ->
    maps:get(Key, Data, Default);

get_value(Key, Data, Default) when is_atom(Key) ->
    case maps:is_key(Key, Data) of
        true -> maps:get(Key, Data);
        false ->
            maps:get((atom_to_binary(Key, utf8)), Data, Default)
    end.


%%------------------------------------------------------------------------------
%% Stop
%%------------------------------------------------------------------------------

%% Called when the rule engine application stop
stop(_Env) ->
    emqx:unhook('client.connected', fun ?MODULE:on_client_connected/4),
    emqx:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
    emqx:unhook('client.subscribe', fun ?MODULE:on_client_subscribe/3),
    emqx:unhook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3),
    emqx:unhook('message.publish', fun ?MODULE:on_message_publish/2),
    emqx:unhook('message.dropped', fun ?MODULE:on_message_dropped/3),
    emqx:unhook('message.deliver', fun ?MODULE:on_message_deliver/3),
    emqx:unhook('message.acked', fun ?MODULE:on_message_acked/3).

bin_key_map(Map) when is_map(Map) ->
    lists:foldl(
        fun(Key, Acc) ->
            Val = maps:get(Key, Map),
            Acc#{bin(Key) => bin_key_map(Val)}
        end, #{}, maps:keys(Map));
bin_key_map(Data) ->
    Data.

bin(Bin) when is_binary(Bin) -> Bin;
bin(Atom) when is_atom(Atom) -> list_to_binary(atom_to_list(Atom));
bin(Str) when is_list(Str) -> list_to_binary(Str).