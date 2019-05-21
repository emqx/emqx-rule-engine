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

-export([ start/1, stop/1 ]).

-export([ on_client_connected/4
        , on_client_disconnected/3
        , on_client_subscribe/3
        , on_client_unsubscribe/3
        , on_message_publish/2
        , on_message_dropped/3
        , on_message_deliver/3
        , on_message_acked/3
        ]).

-import(emqx_rule_maps,
        [ get_value/2
        , get_value/3
        , nested_get/2
        , nested_put/3
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
    emqx:hook(Name, Fun, [Env#{apply_fun => apply_rules_fun(Name)}]).

%%------------------------------------------------------------------------------
%% Callbacks
%%------------------------------------------------------------------------------

on_client_connected(Credentials = #{client_id := ClientId}, ConnAck, ConnAttrs, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Client(~s) connected, connack: ~w", [ClientId, ConnAck]),
    ApplyRules(maps:merge(Credentials, #{event => 'client.connected', connack => ConnAck, connattrs => ConnAttrs})).

on_client_disconnected(Credentials = #{client_id := ClientId}, ReasonCode, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Client(~s) disconnected, reason_code: ~w",
         [ClientId, ReasonCode]),
    ApplyRules(maps:merge(Credentials, #{event => 'client.disconnected', reason_code => ReasonCode})).

on_client_subscribe(Credentials = #{client_id := ClientId}, TopicFilters, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Client(~s) will subscribe: ~p",
         [ClientId, TopicFilters]),
    ApplyRules(maps:merge(Credentials, #{event => 'client.subscribe', topic_filters => TopicFilters})),
    {ok, TopicFilters}.

on_client_unsubscribe(Credentials = #{client_id := ClientId}, TopicFilters, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Client(~s) unsubscribe ~p",
         [ClientId, TopicFilters]),
    ApplyRules(maps:merge(Credentials, #{event => 'client.unsubscribe', topic_filters => TopicFilters})),
    {ok, TopicFilters}.

on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>},
                   #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_publish(Message, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Publish ~s", [emqx_message:format(Message)]),
    ApplyRules(maps:merge(emqx_message:to_map(Message), #{event => 'message.publish'})),
    {ok, Message}.

on_message_dropped(_, Message = #message{topic = <<"$SYS/", _/binary>>},
                   #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_dropped(#{node := Node}, Message, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Message dropped for no subscription: ~s",
         [emqx_message:format(Message)]),
    ApplyRules(maps:merge(emqx_message:to_map(Message), #{event => 'message.dropped', node => Node})),
    {ok, Message}.

on_message_deliver(Credentials = #{client_id := ClientId}, Message, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Deliver message to client(~s): ~s",
         [ClientId, emqx_message:format(Message)]),
    ApplyRules(maps:merge(Credentials#{event => 'message.deliver'}, emqx_message:to_map(Message))),
    {ok, Message}.

on_message_acked(#{client_id := ClientId, username := Username}, Message, #{apply_fun := ApplyRules}) ->
    ?LOG(debug, "[RuleEngine] Session(~s) acked message: ~s",
         [ClientId, emqx_message:format(Message)]),
    ApplyRules(maps:merge(emqx_message:to_map(Message), #{event => 'message.acked', client_id => ClientId, username => Username})),
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
apply_rules([#rule{enabled = false}|More], Input) ->
    apply_rules(More, Input);
apply_rules([Rule = #rule{id = RuleID}|More], Input) ->
    try apply_rule(Rule, Input)
    catch
        _:Error:StkTrace ->
            ?LOG(error, "Apply rule ~s error: ~p. Statcktrace:~n~p",
                 [RuleID, Error, StkTrace])
    end,
    apply_rules(More, Input).

apply_rule(#rule{selects = Selects,
                 conditions = Conditions,
                 actions = Actions}, Input) ->
    Columns = columns(Input),
    Selected = select_and_transform(Selects, Columns),
    match_conditions(Conditions, maps:merge(Columns, Selected))
        andalso take_actions(Actions, Selected, Input).

%% Step1 -> Select and transform data
select_and_transform(Fields, Input) ->
    select_and_transform(Fields, Input, #{}).

select_and_transform([], _Input, Output) ->
    erase_payload(), Output;
select_and_transform(['*'|More], Input, Output) ->
    select_and_transform(More, Input, maps:merge(Output, Input));
select_and_transform([{as, Field, Alias}|More], Input, Output) ->
    Val = eval(Field, Input),
    select_and_transform(More, Input, nested_put(Alias, Val, Output));
select_and_transform([Field|More], Input, Output) ->
    Val = eval(Field, Input),
    Alias = alias(Field, Val),
    select_and_transform(More, Input, nested_put(Alias, Val, Output)).

%% Step2 -> Match selected data with conditions
match_conditions({'and', L, R}, Data) ->
    match_conditions(L, Data) andalso match_conditions(R, Data);
match_conditions({'or', L, R}, Data) ->
    match_conditions(L, Data) orelse match_conditions(R, Data);
match_conditions({'not', Var}, Data) ->
    case eval(Var, Data) of
        Bool when is_boolean(Bool) ->
            not Bool;
        _other -> false
    end;
match_conditions({in, Var, {list, Vals}}, Data) ->
    lists:member(eval(Var, Data), [eval(V, Data) || V <- Vals]);
match_conditions({'fun', Name, Args}, Data) ->
    apply_func(Name, [eval(Arg, Data) || Arg <- Args], Data);
match_conditions({Op, L, R}, Data) when ?is_comp(Op) ->
    compare(Op, eval(L, Data), eval(R, Data));
%%match_conditions({'like', Var, Pattern}, Data) ->
%%    match_like(eval(Var, Data), Pattern);
match_conditions({}, _Data) ->
    true.

%% comparing numbers against strings
compare(Op, L, R) when is_number(L), is_binary(R) ->
    do_compare(Op, L, number(R));
compare(Op, L, R) when is_binary(L), is_number(R) ->
    do_compare(Op, number(L), R);
compare(Op, L, R) ->
    do_compare(Op, L, R).

do_compare('=', L, R) -> L == R;
do_compare('>', L, R) -> L > R;
do_compare('<', L, R) -> L < R;
do_compare('<=', L, R) -> L =< R;
do_compare('>=', L, R) -> L >= R;
do_compare('<>', L, R) -> L /= R;
do_compare('!=', L, R) -> L /= R;
do_compare('=~', T, F) -> emqx_topic:match(T, F).

number(Bin) ->
    try binary_to_integer(Bin)
    catch error:badarg -> binary_to_float(Bin)
    end.

%% Step3 -> Take actions
take_actions(Actions, Selected, Envs) ->
    lists:foreach(fun(Action) -> take_action(Action, Selected, Envs) end, Actions).

take_action(#{apply := Apply}, Selected, Envs) ->
    Apply(Selected, Envs).

eval({var, Var}, Input) -> %% nested
    nested_get(Var, Input);
eval({const, Val}, _Input) ->
    Val;
eval({payload, Attr}, Input) when is_binary(Attr) ->
    get_value(Attr, parse_payload(Input));
eval({payload, AttrPath}, Input) -> %% nested
    nested_get(AttrPath, parse_payload(Input));
eval({Op, L, R}, Input) when ?is_arith(Op) ->
    apply_func(Op, [eval(L, Input), eval(R, Input)], Input);
eval({'fun', Name, Args}, Input) ->
    apply_func(Name, [eval(Arg, Input) || Arg <- Args], Input).

alias(Field, Val) ->
    case alias(Field) of
        undefined -> Val;
        Alias -> Alias
    end.

alias({var, Var}) ->
    Var;
alias({const, Val}) ->
    Val;
alias({payload, Attr}) when is_binary(Attr) ->
    [payload, Attr];
alias({payload, AttrPath}) when is_list(AttrPath) ->
    [payload|AttrPath];
alias(_) -> undefined.

apply_func(Name, Args, Input) when is_atom(Name) ->
    case erlang:apply(emqx_rule_funcs, Name, Args) of
        Func when is_function(Func) ->
            erlang:apply(Func, [Input]);
        Result -> Result
    end.

%% TODO: move to schema registry later.
erase_payload() ->
    erase('$payload').

parse_payload(Input) ->
    case get('$payload') of
        undefined ->
            Payload = get_value(payload, Input, <<"{}">>),
            Json = emqx_json:decode(Payload, [return_maps]),
            put('$payload', Json),
            Json;
        Json -> Json
    end.

%% TODO: is the resource available?
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
    emqx:unhook('message.publish', fun ?MODULE:on_message_publish/2),
    emqx:unhook('message.dropped', fun ?MODULE:on_message_dropped/3),
    emqx:unhook('message.deliver', fun ?MODULE:on_message_deliver/3),
    emqx:unhook('message.acked', fun ?MODULE:on_message_acked/3).

%%------------------------------------------------------------------------------
%% Internal Functions
%%------------------------------------------------------------------------------

columns(Input) ->
    columns(Input, #{}).
columns(Input = #{id := Id}, Result) ->
    columns(maps:remove(id, Input),
            Result#{id => emqx_guid:to_hexstr(Id)});
columns(Input = #{from := From}, Result) ->
    columns(maps:remove(from, Input),
            Result#{client_id => From});
columns(Input = #{headers := Headers}, Result) ->
    Username = maps:get(username, Headers, null),
    Peername = peername(maps:get(peername, Headers, undefined)),
    columns(maps:remove(headers, Input),
            maps:merge(Result, #{username => Username,
                                 peername => Peername}));
columns(Input = #{timestamp := Timestamp}, Result) ->
    columns(maps:remove(timestamp, Input),
            Result#{timestamp => emqx_time:now_ms(Timestamp)});
columns(Input = #{peername := Peername}, Result) ->
    columns(maps:remove(peername, Input),
            Result#{peername => peername(Peername)});
columns(Input = #{connattrs := Conn}, Result) ->
    ConnAt = maps:get(connected_at, Conn, null),
    columns(maps:remove(connattrs, Input),
            maps:merge(Result, #{connected_at => emqx_time:now_ms(ConnAt),
                                 clean_start => maps:get(clean_start, Conn, null),
                                 is_bridge => maps:get(is_bridge, Conn, null),
                                 keepalive => maps:get(keepalive, Conn, null),
                                 proto_ver => maps:get(proto_ver, Conn, null)
                                }));
columns(Input = #{topic_filters := [{Topic, #{qos := QoS}} | _] = Filters}, Result) ->
    columns(maps:remove(topic_filters, Input),
            Result#{topic => Topic, qos => QoS,
                    topic_filters => Filters});
columns(Input, Result) ->
    maps:merge(Result, Input).

peername(undefined) ->
    null;
peername({IPAddr, Port}) ->
    list_to_binary(inet:ntoa(IPAddr) ++ ":" ++ integer_to_list(Port)).