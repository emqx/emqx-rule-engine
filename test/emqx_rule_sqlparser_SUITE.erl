%%--------------------------------------------------------------------
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
%%--------------------------------------------------------------------

-module(emqx_rule_sqlparser_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

%%-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

%%------------------------------------------------------------------------------
%% Test cases for sqlparser
%%------------------------------------------------------------------------------

t_sqlparse(_Config) ->
    {ok, Select} = emqx_rule_sqlparser:parse_select("select * "
                                                    "from \"message.publish\" "
                                                    "where topic = 'topic/#' and payload.x > 10 and payload.y <= 20"),
    ?assertEqual(['*'], emqx_rule_sqlparser:select_fields(Select)),
    ?assertEqual(['message.publish'], emqx_rule_sqlparser:select_from(Select)),
    ?assertEqual({'and',{'and',{'=',{var,<<"topic">>},{const,<<"topic/#">>}},
                               {'>',{var,[<<"payload">>, <<"x">>]},{const,10}}},
                        {'<=',{var,[<<"payload">>, <<"y">>]},{const,20}}},
                 emqx_rule_sqlparser:select_where(Select)),
    %% test null where
    {ok, Select1} = emqx_rule_sqlparser:parse_select("select * from \"message.publish\""),
    ?assertEqual({}, emqx_rule_sqlparser:select_where(Select1)),
    %% test trim alias
    {ok, Select2} = emqx_rule_sqlparser:parse_select("select payload.x as payload.y from \"message.publish\" where topic='topic'"),
    ?assertEqual([{'as', {var,[<<"payload">>, <<"x">>]}, [<<"payload">>, <<"y">>]}],
                  emqx_rule_sqlparser:select_fields(Select2)).

t_sqlparse_error(_) ->
    ?assertMatch({parse_error, _}, emqx_rule_sqlparser:parse_select("select *")).

t_sqlparse_where_in(_) ->
    {ok, Select} = emqx_rule_sqlparser:parse_select("select payload.a, payload.b, payload.c as c "
                                                    "from \"message.publish\" "
                                                    "where c in (1, 2, 3)"),
    ?assertEqual([{var,[<<"payload">>, <<"a">>]},
                  {var,[<<"payload">>, <<"b">>]},
                  {as,{var,[<<"payload">>, <<"c">>]},<<"c">>}],
                 emqx_rule_sqlparser:select_fields(Select)),
    ?assertEqual({'in', {var, <<"c">>}, {list, [{const, 1}, {const, 2}, {const, 3}]}},
                 emqx_rule_sqlparser:select_where(Select)).

t_sqlparse_where_not(_) ->
    Sql = "select sqrt(payload.x) as a, payload.y as b from \"message.publish\" where (not b) and a > 0",
    {ok, Select} = emqx_rule_sqlparser:parse_select(Sql),
    ?assertMatch({'and', {'not',{var,<<"b">>}}, _}, emqx_rule_sqlparser:select_where(Select)).

t_sqlparse_op(_) ->
    Sql = "select payload.x + payload.y as c, payload.x div payload.y as a from \"message.publish\"",
    {ok, Select} = emqx_rule_sqlparser:parse_select(Sql),
    Ops = [Op || {as, Op, _} <- emqx_rule_sqlparser:select_fields(Select)],
    ?assertMatch([{'+', _, _}, {'div', _, _}], Ops).
    
    
% t_unquote(_) ->
%     error('TODO').

% t_hook(_) ->
%     error('TODO').

% t_select_where(_) ->
%     error('TODO').

% t_select_fields(_) ->
%     error('TODO').

% t_select_from(_) ->
%     error('TODO').

% t_parse_select(_) ->
%     error('TODO').


all() ->
    IsTestCase = fun("t_" ++ _) -> true; (_) -> false end,
    [F || {F, _A} <- module_info(exports), IsTestCase(atom_to_list(F))].

suite() ->
    [{ct_hooks, [cth_surefire]}, {timetrap, {seconds, 30}}].

