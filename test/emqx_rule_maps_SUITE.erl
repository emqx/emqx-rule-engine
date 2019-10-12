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

-module(emqx_rule_maps_SUITE).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

-export([ t_get_put_value/1
        , t_prop_get_put/1
        , t_nested_get/1
        , t_nested_put/1
        , t_atom_key_map/1
        ]).

-export([ all/0
        , suite/0
        ]).

-import(emqx_rule_maps,
        [ nested_get/2
        , nested_put/3
        , get_value/2
        , get_value/3
        , put_value/3
        , atom_key_map/1
        ]).

-define(PROPTEST(Prop), true = proper:quickcheck(Prop)).

t_nested_put(_) ->
    ?assertEqual(#{a => 1}, nested_put(a, 1, #{})),
    ?assertEqual(#{a => a}, nested_put([a], a, #{})),
    ?assertEqual(#{a => 1}, nested_put(a, 1, b)),
    ?assertEqual(#{a => #{b => b}}, nested_put([a,b], b, #{})),
    ?assertEqual(#{a => #{b => #{c => c}}}, nested_put([a,b,c], c, #{})),
    ?assertEqual(#{<<"k">> => v1}, nested_put(k, v1, #{<<"k">> => v0})),
    ?assertEqual(#{k => v1}, nested_put(k, v1, #{k => v0})),
    ?assertEqual(#{<<"k">> => v1, a => b}, nested_put(k, v1, #{<<"k">> => v0, a => b})),
    ?assertEqual(#{<<"k">> => v1}, nested_put([k], v1, #{<<"k">> => v0})),
    ?assertEqual(#{k => v1}, nested_put([k], v1, #{k => v0})),
    ?assertEqual(#{k => v1, a => b}, nested_put([k], v1, #{k => v0, a => b})),
    ?assertEqual(#{<<"k">> => v1, a => b}, nested_put([k], v1, #{<<"k">> => v0, a => b})),
    ?assertEqual(#{<<"k">> => #{<<"t">> => v1}}, nested_put([k,t], v1, #{<<"k">> => #{<<"t">> => v0}})),
    ?assertEqual(#{<<"k">> => #{t => v1}}, nested_put([k,t], v1, #{<<"k">> => #{t => v0}})),
    ?assertEqual(#{k => #{<<"t">> => #{a => v1}}}, nested_put([k,t,a], v1, #{k => #{<<"t">> => v0}})),
    ?assertEqual(#{k => #{<<"t">> => #{<<"a">> => v1}}}, nested_put([k,t,<<"a">>], v1, #{k => #{<<"t">> => v0}})).

t_nested_get(_) ->
    ?assertEqual(undefined, nested_get(a, not_map)),
    ?assertEqual(undefined, nested_get([a,b,c], not_map)),
    ?assertEqual(undefined, nested_get([a,b,c], #{})),
    ?assertEqual(undefined, nested_get([a,b,c], #{a => #{}})),
    ?assertEqual(undefined, nested_get([a,b,c], #{a => #{b => #{}}})),
    ?assertEqual(v1, nested_get([p,x], #{p => #{x => v1}})),
    ?assertEqual(v1, nested_get([<<"p">>,<<"x">>], #{p => #{x => v1}})),
    ?assertEqual(c, nested_get([a,b,c], #{a => #{b => #{c => c}}})).

t_get_put_value(_) ->
    ?assertEqual(#{}, put_value(k, undefined, #{})),
    ?assertEqual(#{k => v}, put_value(k, v, #{})),
    ?assertEqual(#{<<"k">> => v}, put_value(<<"k">>, v, #{})),
    ?assertEqual(#{<<"k">> => v}, put_value(k, undefined, #{<<"k">> => v})),
    ?assertEqual(undefined, get_value(k, #{})),
    ?assertEqual(v, get_value(<<"k">>, #{k=> v})),
    ?assertEqual(v, get_value(k, #{k=> v})),
    ?assertEqual(v, get_value(<<"k">>, #{k => v}, d)),
    ?assertEqual(v, get_value(k, #{k => v}, d)),
    ?assertEqual(d, get_value(<<"k">>, #{}, d)),
    ?assertEqual(d, get_value(k, #{}, d)).

t_prop_get_put(_) ->
    ?assert(proper:quickcheck(prop_get_put_value())).

t_atom_key_map(_) ->
    ?assertEqual(#{a => 1}, atom_key_map(#{<<"a">> => 1})),
    ?assertEqual(#{a => 1, b => #{a => 2}},
                 atom_key_map(#{<<"a">> => 1, <<"b">> => #{<<"a">> => 2}})),
    ?assertEqual([#{a => 1}, #{b => #{a => 2}}],
                 atom_key_map([#{<<"a">> => 1}, #{<<"b">> => #{<<"a">> => 2}}])),
    ?assertEqual(#{a => 1, b => [#{a => 2}, #{c => 2}]},
                 atom_key_map(#{<<"a">> => 1, <<"b">> => [#{<<"a">> => 2}, #{<<"c">> => 2}]})).

prop_get_put_value() ->
    ?FORALL({Key, Val}, {term(), term()},
            begin
                Val =:= get_value(Key, put_value(Key, Val, #{}))
            end).

all() ->
    IsTestCase = fun("t_" ++ _) -> true; (_) -> false end,
    [F || {F, _A} <- module_info(exports), IsTestCase(atom_to_list(F))].

suite() ->
    [{ct_hooks, [cth_surefire]}, {timetrap, {seconds, 30}}].

