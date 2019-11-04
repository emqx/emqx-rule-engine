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

-module(emqx_rule_sqltester).

-include("rule_engine.hrl").
-include("rule_events.hrl").
-include_lib("emqx/include/logger.hrl").

-export([ test/1
        ]).

-spec(test(#{}) -> {ok, Result::map()} | no_return()).
test(#{<<"rawsql">> := Sql, <<"ctx">> := Context}) ->
    case emqx_rule_sqlparser:parse_select(Sql) of
        {ok, Select} ->
            Event = emqx_rule_sqlparser:select_from(Select),
            ActInstId = {test_rule_sql, self()},
            Rule = #rule{rawsql = Sql,
                         for = Event,
                         is_foreach = emqx_rule_sqlparser:select_is_foreach(Select),
                         fields = emqx_rule_sqlparser:select_fields(Select),
                         doeach = emqx_rule_sqlparser:select_doeach(Select),
                         incase = emqx_rule_sqlparser:select_incase(Select),
                         conditions = emqx_rule_sqlparser:select_where(Select),
                         actions = [#action_instance{
                                        id = ActInstId,
                                        name = test_rule_sql}]},
            FullContext = fill_default_values(hd(Event), emqx_rule_maps:atom_key_map(Context), #{}),
            try
                ok = emqx_rule_registry:add_action_instance_params(
                        #action_instance_params{id = ActInstId,
                                                params = #{},
                                                apply = sql_test_action()}),
                emqx_rule_runtime:apply_rule(Rule, FullContext)
            of
                {ok, Data} -> {ok, flatten(Data)};
                {error, nomatch} -> {error, nomatch}
            after
                ok = emqx_rule_registry:remove_action_instance_params(ActInstId)
            end;
        Error -> error(Error)
    end.

flatten([D1]) -> D1;
flatten([D1 | L]) when is_list(D1) ->
    D1 ++ flatten(L).

sql_test_action() ->
    fun(Data, _Envs) ->
        ?LOG(info, "Testing Rule SQL OK"), Data
    end.

fill_default_values(Event, #{topic_filters := TopicFilters} = Context, Result) ->
    fill_default_values(Event, maps:remove(topic_filters, Context),
                        Result#{topic_filters => parse_topic_filters(TopicFilters)});
fill_default_values(Event, #{peername := Peername} = Context, Result) ->
    fill_default_values(Event, maps:remove(peername, Context),
                        Result#{peername => parse_peername(Peername)});
fill_default_values(Event, Context, Acc) ->
    maps:merge(?EG_ENVS(Event), maps:merge(Context, Acc)).

parse_peername(Peername) ->
    case string:split(Peername, [$:]) of
        [IPAddrStr, PortStr] ->
            IPAddr = case inet:parse_address("127.0.0.1") of
                        {ok, IPAddr0} -> IPAddr0;
                        {error, Error} -> error({Error, IPAddrStr})
                     end,
            {IPAddr, binary_to_integer(PortStr)};
        [IPAddrStr] ->
            error({invalid_ip_port, IPAddrStr})
    end.

parse_topic_filters(TopicFilters) ->
    [ case TpcFtl of
        #{<<"topic">> := Topic, <<"qos">> := QoS} ->
            {Topic, #{qos => QoS}};
        #{<<"topic">> := Topic} ->
            {Topic, #{}};
        Topic ->
            {Topic, #{}}
      end || TpcFtl <- jsx:decode(TopicFilters, [return_maps])].
