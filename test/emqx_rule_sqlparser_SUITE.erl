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

-module(emqx_rule_sqlparser_SUITE).

%%-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

%% test cases for emqx_rule_sqlparser
-export([t_sqlparse/1]).

-export([ all/0
        , suite/0
        ]).

%%------------------------------------------------------------------------------
%% Test cases for sqlparser
%%------------------------------------------------------------------------------

t_sqlparse(_Config) ->
    {ok, Select} = emqx_rule_sqlparser:parse_select("select * from \"topic/#\" where x > 10 and y <= 20"),
    ?assertEqual(['*'], emqx_rule_sqlparser:select_fields(Select)),
    ?assertEqual([<<"topic/#">>], emqx_rule_sqlparser:select_from(Select)),
    ?assertEqual({'and', {'>', {var, [<<"x">>]}, {const, 10}},
                         {'<=',{var, [<<"y">>]}, {const, 20}}},
                 emqx_rule_sqlparser:select_where(Select)).

all() ->
    IsTestCase = fun("t_" ++ _) -> true; (_) -> false end,
    [F || {F, _A} <- module_info(exports), IsTestCase(atom_to_list(F))].

suite() ->
    [{ct_hooks, [cth_surefire]}, {timetrap, {seconds, 30}}].

