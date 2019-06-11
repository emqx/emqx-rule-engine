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

-module(emqx_rule_utils_tests).

-include_lib("eunit/include/eunit.hrl").

preproc_tmpl_test_() ->
    [ ?_assertMatch([{str, <<"value: a">>} | _], emqx_rule_utils:preproc_tmpl(<<"value: a">>))
    , ?_assertMatch([{str, <<"value: ">>} | _], emqx_rule_utils:preproc_tmpl(<<"value: ${a}">>))
    , ?_assertMatch([{str,<<"key: ">>}, {var,_},
                    {str,<<", value: ">>}, {var,_},
                    {str,<<".">>}], emqx_rule_utils:preproc_tmpl(<<"key: ${k}, value: ${v}.">>))
    ].

proc_tmpl_test_() ->
    Tokens0 = emqx_rule_utils:preproc_tmpl(<<"key: ${k}, value: ${v}.">>),
    Tokens1 = emqx_rule_utils:preproc_tmpl(<<"str = ${k}:${v}:${k}.">>),
    [ ?_assertEqual(<<"key: greet, value: hello.">>, emqx_rule_utils:proc_tmpl(Tokens0, #{k => greet, v => hello}))
    , ?_assertEqual(<<"str = greet:hello:greet.">>, emqx_rule_utils:proc_tmpl(Tokens1, #{k => greet, v => hello}))
    ].

preproc_sql1_test() ->
    {Tk, GetV} = emqx_rule_utils:preproc_sql(<<"value: a">>, '?'),
    ?assertEqual(<<"value: a">>, Tk),
    ?assertEqual([], GetV(#{k => v})).

preproc_sql2_test() ->
    {Tk, GetV} = emqx_rule_utils:preproc_sql(<<"v1: ${a}, v2: ${b}">>, '?'),
    ?assertEqual(<<"v1: ?, v2: ?">>, Tk),
    ?assertEqual([1, 2], GetV(#{a => 1, b => 2})).

preproc_sql3_test() ->
    {Tk, GetV} = emqx_rule_utils:preproc_sql(<<"v1: ${a}, v2: ${b}">>, '$n'),
    ?assertEqual(<<"v1: $1, v2: $2">>, Tk),
    ?assertEqual([<<"hello">>, <<"yes">>], GetV(#{a => hello, b => <<"yes">> })).
