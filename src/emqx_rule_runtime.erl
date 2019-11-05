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
        , on_session_subscribed/4
        , on_session_unsubscribed/4
        , on_message_publish/2
        , on_message_dropped/3
        , on_message_deliver/3
        , on_message_acked/3
        ]).

-export([ apply_rule/2
        , clear_rule_payload/0
        ]).

-import(emqx_rule_maps,
        [ nested_get/2
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
    hook_rules('session.subscribed', fun ?MODULE:on_session_subscribed/4, Env),
    hook_rules('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4, Env),
    hook_rules('message.publish', fun ?MODULE:on_message_publish/2, Env),
    hook_rules('message.dropped', fun ?MODULE:on_message_dropped/3, Env),
    hook_rules('message.deliver', fun ?MODULE:on_message_deliver/3, Env),
    hook_rules('message.acked', fun ?MODULE:on_message_acked/3, Env),
    ok.

hook_rules(Name, Fun, Env) ->
    emqx:hook(Name, Fun, [Env#{apply_fun => apply_rules_fun(Name)}]).

%%------------------------------------------------------------------------------
%% Stop
%%------------------------------------------------------------------------------
%% Called when the rule engine application stop
stop(_Env) ->
    emqx:unhook('client.connected', fun ?MODULE:on_client_connected/4),
    emqx:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
    emqx:unhook('client.subscribe', fun ?MODULE:on_client_subscribe/3),
    emqx:unhook('client.unsubscribe', fun ?MODULE:on_client_unsubscribe/3),
    emqx:unhook('session.subscribed', fun ?MODULE:on_session_subscribed/4),
    emqx:unhook('session.unsubscribed', fun ?MODULE:on_session_unsubscribed/4),
    emqx:unhook('message.publish', fun ?MODULE:on_message_publish/2),
    emqx:unhook('message.dropped', fun ?MODULE:on_message_dropped/3),
    emqx:unhook('message.deliver', fun ?MODULE:on_message_deliver/3),
    emqx:unhook('message.acked', fun ?MODULE:on_message_acked/3),
    ok.

%%------------------------------------------------------------------------------
%% Callbacks
%%------------------------------------------------------------------------------

on_client_connected(Credentials, ConnAck, ConnAttrs, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(Credentials, #{event => 'client.connected', connack => ConnAck, connattrs => ConnAttrs, node => node()})).

on_client_disconnected(Credentials, ReasonCode, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(Credentials, #{event => 'client.disconnected', reason_code => ReasonCode, node => node(), timestamp => erlang:timestamp()})).

on_client_subscribe(Credentials, TopicFilters, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(Credentials, #{event => 'client.subscribe', topic_filters => TopicFilters, node => node(), timestamp => erlang:timestamp()})),
    {ok, TopicFilters}.

on_client_unsubscribe(Credentials, TopicFilters, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(Credentials, #{event => 'client.unsubscribe', topic_filters => TopicFilters, node => node(), timestamp => erlang:timestamp()})),
    {ok, TopicFilters}.

on_session_subscribed(ClientInfo, Topic, SubOpts, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(ClientInfo, #{event => 'session.subscribed', topic => Topic, node => node(), timestamp => erlang:timestamp(), sub_opts => SubOpts})).

on_session_unsubscribed(ClientInfo, Topic, SubOpts, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(ClientInfo, #{event => 'session.unsubscribed', topic => Topic, node => node(), timestamp => erlang:timestamp(), sub_opts => SubOpts})).

on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>},
                   #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_publish(Message, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(emqx_message:to_map(Message), #{event => 'message.publish', node => node()})),
    {ok, Message}.

on_message_dropped(_, Message = #message{topic = <<"$SYS/", _/binary>>},
                   #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_dropped(_, Message, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(emqx_message:to_map(Message), #{event => 'message.dropped', node => node()})),
    {ok, Message}.

on_message_deliver(Credentials, Message, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(Credentials#{event => 'message.deliver', node => node()}, emqx_message:to_map(Message))),
    {ok, Message}.

on_message_acked(#{client_id := ClientId, username := Username}, Message, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(emqx_message:to_map(Message), #{event => 'message.acked', client_id => ClientId, username => Username, node => node()})),
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
    clear_rule_payload(),
    ok;
apply_rules([#rule{enabled = false}|More], Input) ->
    apply_rules(More, Input);
apply_rules([Rule = #rule{id = RuleID}|More], Input) ->
    try apply_rule(Rule, Input)
    catch
        %% ignore the errors if select or match failed
        _:{select_and_transform_error, Error} ->
            ?LOG(debug, "SELECT clause exception for ~s failed: ~p",
                 [RuleID, Error]);
        _:{match_conditions_error, Error} ->
            ?LOG(debug, "WHERE clause exception for ~s failed: ~p",
                 [RuleID, Error]);
        _:Error:StkTrace ->
            ?LOG(error, "Apply rule ~s failed: ~p. Stacktrace:~n~p",
                 [RuleID, Error, StkTrace])
    end,
    apply_rules(More, Input).

apply_rule(#rule{id = RuleId,
                 is_foreach = true,
                 fields = Fields,
                 doeach = DoEach,
                 incase = InCase,
                 conditions = Conditions,
                 actions = Actions}, Input) ->
    Columns = columns(Input),
    {Selected, Collection} = ?RAISE(select_and_collect(Fields, Columns),
                                        {select_and_collect_error, _REASON_}),
    ColumnsAndSelected = maps:merge(Columns, Selected),
    case ?RAISE(match_conditions(Conditions, ColumnsAndSelected),
                {match_conditions_error, _REASON_}) of
        true ->
            ok = emqx_rule_metrics:inc(RuleId, 'rules.matched'),
            Collection2 = filter_collection(Input, InCase, DoEach, Collection),
            {ok, [take_actions(Actions, Coll, Input) || Coll <- Collection2]};
        false ->
            {error, nomatch}
    end;

apply_rule(#rule{id = RuleId,
                 is_foreach = false,
                 fields = Fields,
                 conditions = Conditions,
                 actions = Actions}, Input) ->
    Columns = columns(Input),
    Selected = ?RAISE(select_and_transform(Fields, Columns),
                      {select_and_transform_error, _REASON_}),
    case ?RAISE(match_conditions(Conditions, maps:merge(Columns, Selected)),
                {match_conditions_error, _REASON_}) of
        true ->
            ok = emqx_rule_metrics:inc(RuleId, 'rules.matched'),
            {ok, take_actions(Actions, Selected, Input)};
        false ->
            {error, nomatch}
    end.

clear_rule_payload() ->
    erlang:erase(rule_payload).

%% Step1 -> Select and transform data
select_and_transform(Fields, Input) ->
    select_and_transform(Fields, Input, #{}).

select_and_transform([], _Input, Output) ->
    Output;
select_and_transform(['*'|More], Input, Output) ->
    select_and_transform(More, Input, maps:merge(Output, Input));
select_and_transform([{as, Field, Alias}|More], Input, Output) ->
    Key = emqx_rule_utils:unsafe_atom_key(Alias),
    Val = eval(Field, Input),
    select_and_transform(More,
        nested_put(Key, Val, Input),
        nested_put(Key, Val, Output));
select_and_transform([Field|More], Input, Output) ->
    Val = eval(Field, Input),
    Key = alias(Field, Val),
    select_and_transform(More,
        nested_put(Key, Val, Input),
        nested_put(Key, Val, Output)).

%% foreach clause
select_and_collect(Fields, Input) ->
    select_and_collect(Fields, Input, {#{}, {'item', []}}).

select_and_collect([{as, Field, Alias}], Input, {Output, _}) ->
    Key = emqx_rule_utils:unsafe_atom_key(Alias),
    Val = eval(Field, Input),
    {nested_put(Key, Val, Output), {Key, Val}};
select_and_collect([{as, Field, Alias}|More], Input, {Output, LastKV}) ->
    Key = emqx_rule_utils:unsafe_atom_key(Alias),
    Val = eval(Field, Input),
    select_and_collect(More,
        nested_put(Key, Val, Input),
        {nested_put(Key, Val, Output), LastKV});
select_and_collect([Field], Input, {Output, _}) ->
    Val = eval(Field, Input),
    Key = alias(Field, Val),
    {nested_put(Key, Val, Output), {'item', Val}};
select_and_collect([Field|More], Input, {Output, LastKV}) ->
    Val = eval(Field, Input),
    Key = alias(Field, Val),
    select_and_collect(More,
        nested_put(Key, Val, Input),
        {nested_put(Key, Val, Output), LastKV}).

%% filter each item
filter_collection(Input, InCase, DoEach, {CollKey, CollVal}) ->
    lists:filtermap(
        fun(Item) ->
            InputAndItem = maps:merge(Input, #{CollKey => Item}),
            case ?RAISE(match_conditions(InCase, InputAndItem),
                    {match_conditions_error, _REASON_}) of
                true when DoEach == [] -> true;
                true ->
                    {true, ?RAISE(select_and_transform(DoEach, InputAndItem),
                                  {doeach_error, _REASON_})};
                false -> false
            end
        end, CollVal).

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
    lists:map(fun(Action) -> take_action(Action, Selected, Envs) end, Actions).

take_action(#action_instance{id = Id}, Selected, Envs) ->
    try
        {ok, #action_instance_params{apply = Apply}}
            = emqx_rule_registry:get_action_instance_params(Id),
        Result = Apply(Selected, Envs),
        emqx_rule_metrics:inc(Id, 'actions.success'),
        Result
    catch
        _Error:Reason:Stack ->
            emqx_rule_metrics:inc(Id, 'actions.failure'),
            error({take_action_failed, {Id, Reason, Stack}})
    end.

eval({var, [<<"payload">> | Vars]}, Input) ->
    nested_get(Vars,
        case erlang:get(rule_payload) of
            undefined ->
                Map = ensure_map(nested_get(<<"payload">>, Input)),
                erlang:put(rule_payload, Map), Map;
            Map -> Map
        end);
eval({var, Var}, Input) ->
    nested_get(Var, Input);
eval({const, Val}, _Input) ->
    Val;
eval({Op, L, R}, Input) when ?is_arith(Op) ->
    apply_func(Op, [eval(L, Input), eval(R, Input)], Input);
eval({'case', undefined, CaseClauses, ElseClauses}, Input) ->
    eval_case_clauses(CaseClauses, ElseClauses, Input);
eval({'case', CaseOn, CaseClauses, ElseClauses}, Input) ->
    eval_switch_clauses(CaseOn, CaseClauses, ElseClauses, Input);
eval({'fun', Name, Args}, Input) ->
    apply_func(Name, [eval(Arg, Input) || Arg <- Args], Input).

alias(Field, Val) ->
    case alias(Field) of
        undefined -> Val;
        Alias -> Alias
    end.

alias({var, Var}) ->
    emqx_rule_utils:unsafe_atom_key(Var);
alias({const, Val}) ->
    Val;
alias(_) -> undefined.

eval_case_clauses([], ElseClauses, Input) ->
    case ElseClauses of
        undefined -> undefined;
        _ -> eval(ElseClauses, Input)
    end;
eval_case_clauses([{Cond, Clause} | CaseClauses], ElseClauses, Input) ->
    case match_conditions(Cond, Input) of
        true ->
            eval(Clause, Input);
        _ ->
            eval_case_clauses(CaseClauses, ElseClauses, Input)
    end.

eval_switch_clauses(_CaseOn, [], ElseClauses, Input) ->
    case ElseClauses of
        undefined -> undefined;
        _ -> eval(ElseClauses, Input)
    end;
eval_switch_clauses(CaseOn, [{Cond, Clause} | CaseClauses], ElseClauses, Input) ->
    ConResult = eval(Cond, Input),
    case eval(CaseOn, Input) of
        ConResult ->
            eval(Clause, Input);
        _ ->
            eval_switch_clauses(CaseOn, CaseClauses, ElseClauses, Input)
    end.

apply_func(Name, Args, Input) when is_atom(Name) ->
    case erlang:apply(emqx_rule_funcs, Name, Args) of
        Func when is_function(Func) ->
            erlang:apply(Func, [Input]);
        Result -> Result
    end.

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
columns(Input = #{flags := Flags}, Result) ->
    Retain = maps:get(retain, Flags, false),
    columns(maps:remove(flags, Input),
            maps:merge(Result, #{retain => int(Retain)}));
columns(Input = #{headers := Headers}, Result) ->
    Username = maps:get(username, Headers, undefined),
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
columns(Input = #{sockname := Peername}, Result) ->
    columns(maps:remove(sockname, Input),
            Result#{sockname => peername(Peername)});
columns(Input = #{connattrs := Conn}, Result) ->
    ConnAt = maps:get(connected_at, Conn, undefined),
    columns(maps:remove(connattrs, Input),
            maps:merge(Result, #{connected_at => emqx_time:now_ms(ConnAt),
                                 clean_start => maps:get(clean_start, Conn, undefined),
                                 is_bridge => maps:get(is_bridge, Conn, undefined),
                                 keepalive => maps:get(keepalive, Conn, undefined),
                                 proto_ver => maps:get(proto_ver, Conn, undefined)
                                }));
columns(Input = #{topic_filters := [{Topic, Opts} | _] = Filters}, Result) ->
    columns(maps:remove(topic_filters, Input),
            Result#{topic => Topic, qos => maps:get(qos, Opts, 0),
                    topic_filters => format_topic_filters(Filters)});
columns(Input, Result) ->
    maps:merge(Result, Input).

peername(undefined) ->
    undefined;
peername({IPAddr, Port}) ->
    list_to_binary(inet:ntoa(IPAddr) ++ ":" ++ integer_to_list(Port)).

int(true) -> 1;
int(false) -> 0.

format_topic_filters(Filters) ->
    [begin
        #{topic => Topic, qos => maps:get(qos, Opts, 0), sub_opts => Opts}
     end || {Topic, Opts} <- Filters].

ensure_map(Map) when is_map(Map) ->
    Map;
ensure_map(MaybeJson) ->
    try jsx:decode(MaybeJson, [return_maps]) of
        JsonMap when is_map(JsonMap) -> JsonMap;
        _Val -> #{}
    catch _:_ -> #{}
    end.
