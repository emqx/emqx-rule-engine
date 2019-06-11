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

-module(emqx_rule_metrics_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

all() ->
    [ {group, metrics}
    , {group, speed} ].

suite() ->
    [{ct_hooks, [cth_surefire]}, {timetrap, {seconds, 30}}].

groups() ->
    [{metrics, [sequence],
        [ t_action
        , t_rule
        , t_invalid_metric
        , t_clear
        ]},
    {speed, [sequence],
        [ rule_speed
        ]}
    ].


init_per_testcase(_, Config) ->
    {ok, _} = emqx_rule_metrics:start_link(),
    Config.

end_per_testcase(_, _Config) ->
    emqx_rule_metrics:stop(),
    ok.

t_action(_) ->
    ?assertEqual(not_found, emqx_rule_metrics:get(<<"action:1">>, 'actions.success')),
    ?assertEqual(not_found, emqx_rule_metrics:get(<<"action:1">>, 'actions.failed')),
    ?assertEqual(not_found, emqx_rule_metrics:get(<<"action:2">>, 'actions.success')),
    ok = emqx_rule_metrics:inc(<<"action:1">>, 'actions.success'),
    ok = emqx_rule_metrics:inc(<<"action:1">>, 'actions.failed'),
    ok = emqx_rule_metrics:inc(<<"action:2">>, 'actions.success'),
    ok = emqx_rule_metrics:inc(<<"action:2">>, 'actions.success'),
    ?assertEqual(1, emqx_rule_metrics:get(<<"action:1">>, 'actions.success')),
    ?assertEqual(1, emqx_rule_metrics:get(<<"action:1">>, 'actions.failed')),
    ?assertEqual(2, emqx_rule_metrics:get(<<"action:2">>, 'actions.success')),
    ?assertEqual(not_found, emqx_rule_metrics:get(<<"action:3">>, 'actions.success')),
    ?assertEqual(3, emqx_rule_metrics:get_overall('actions.success')),
    ?assertEqual(1, emqx_rule_metrics:get_overall('actions.failed')).

t_rule(_) ->
    ok = emqx_rule_metrics:inc(<<"rule:1">>, 'rule.matched'),
    ok = emqx_rule_metrics:inc(<<"rule:1">>, 'rule.nomatch'),
    ok = emqx_rule_metrics:inc(<<"rule:2">>, 'rule.matched'),
    ok = emqx_rule_metrics:inc(<<"rule:2">>, 'rule.matched'),
    ok = emqx_rule_metrics:inc(<<"rule:2">>, 'rule.nomatch'),
    ?assertEqual(1, emqx_rule_metrics:get(<<"rule:1">>, 'rule.matched')),
    ?assertEqual(1, emqx_rule_metrics:get(<<"rule:1">>, 'rule.nomatch')),
    ?assertEqual(2, emqx_rule_metrics:get(<<"rule:2">>, 'rule.matched')),
    ?assertEqual(1, emqx_rule_metrics:get(<<"rule:2">>, 'rule.nomatch')),
    ?assertEqual(not_found, emqx_rule_metrics:get(<<"rule:3">>, 'rule.matched')),
    ?assertEqual(3, emqx_rule_metrics:get_overall('rule.matched')),
    ?assertEqual(2, emqx_rule_metrics:get_overall('rule.nomatch')).

t_invalid_metric(_) ->
    ok = emqx_rule_metrics:inc(<<"rule:1">>, 'invalid_metric'),
    ok = emqx_rule_metrics:inc(<<"rule:1">>, 'invalid_metric2'),
    ?assert(emqx_rule_metrics:get(<<"rule:1">>, 'invalid_metric') >= 0).

t_clear(_) ->
    ok = emqx_rule_metrics:inc(<<"action:1">>, 'actions.success'),
    ?assertEqual(1, emqx_rule_metrics:get(<<"action:1">>, 'actions.success')),
    ok = emqx_rule_metrics:clear(<<"action:1">>),
    ?assertEqual(not_found, emqx_rule_metrics:get(<<"action:1">>, 'actions.success')).

rule_speed(_) ->
    ok = emqx_rule_metrics:inc(<<"rule:1">>, 'rule.matched'),
    ok = emqx_rule_metrics:inc(<<"rule:1">>, 'rule.matched'),
    ok = emqx_rule_metrics:inc(<<"rule:2">>, 'rule.matched'),
    ?assertEqual(2, emqx_rule_metrics:get(<<"rule:1">>, 'rule.matched')),
    ct:sleep(1000),
    ?LET(#{max := Max, current := Current}, emqx_rule_metrics:get_rule_speed(<<"rule:1">>),
         {?assert(Max == 2),
          ?assert(Current == 2)}),
    ?LET(#{max := Max, current := Current}, emqx_rule_metrics:get_overall_rule_speed(),
         {?assert(Max == 3),
          ?assert(Current == 3)}),
    ct:sleep(2100),
    ?LET(#{max := Max, current := Current, last5m := Last5Min}, emqx_rule_metrics:get_rule_speed(<<"rule:1">>),
         {?assert(Max == 2),
          ?assert(Current == 0),
          ?assert(Last5Min =< 0.67)}),
    ?LET(#{max := Max, current := Current, last5m := Last5Min}, emqx_rule_metrics:get_overall_rule_speed(),
         {?assert(Max == 3),
          ?assert(Current == 0),
          ?assert(Last5Min =< 1)}),
    ct:sleep(3000),
    ?LET(#{max := Max, current := Current, last5m := Last5Min}, emqx_rule_metrics:get_overall_rule_speed(),
         {?assert(Max == 3),
          ?assert(Current == 0),
          ?assert(Last5Min == 0)}).
