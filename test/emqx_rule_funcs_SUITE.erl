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

-module(emqx_rule_funcs_SUITE).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

%% IoT funcs test cases
-export([ t_msgid/1
        , t_qos/1
        , t_flags/1
        , t_flag/1
        , t_headers/1
        , t_header/1
        , t_topic/1
        , t_clientid/1
        , t_clientip/1
        , t_peername/1
        , t_username/1
        , t_payload/1
        , t_timestamp/1
        ]).


%% Arith op test cases
-export([ t_arith_op/1 ]).

-export([ all/0
        , suite/0
        ]).

%%------------------------------------------------------------------------------
%% Cases for IoT Funcs
%%------------------------------------------------------------------------------

t_msgid(_) ->
    Msg = message(),
    ?assertEqual(undefined, apply_func(msgid, [], #{})),
    ?assertEqual(emqx_message:id(Msg), apply_func(msgid, [], Msg)).

t_qos(_) ->
    ?assertEqual(undefined, apply_func(qos, [], #{})),
    ?assertEqual(1, apply_func(qos, [], message())).

t_flags(_) ->
    ?assertEqual(#{dup => false}, apply_func(flags, [], message())).

t_flag(_) ->
    Msg = message(),
    Msg1 = emqx_message:set_flag(retain, Msg),
    ?assertNot(apply_func(flag, [dup], Msg)),
    ?assert(apply_func(flag, [retain], Msg1)).

t_headers(_) ->
    Msg = emqx_message:set_header(username, admin, message()),
    ?assertEqual(#{}, apply_func(headers, [], #{})),
    ?assertEqual(#{username => admin}, apply_func(headers, [], Msg)).

t_header(_) ->
    Msg = emqx_message:set_header(username, admin, message()),
    ?assertEqual(admin, apply_func(header, [username], Msg)).

t_topic(_) ->
    Msg = message(),
    ?assertEqual(<<"topic/#">>, apply_func(topic, [], Msg)),
    ?assertEqual(<<"topic">>, apply_func(topic, [1], Msg)).

t_clientid(_) ->
    Msg = message(),
    ?assertEqual(undefined, apply_func(clientid, [], #{})),
    ?assertEqual(<<"clientid">>, apply_func(clientid, [], Msg)).

t_clientip(_) ->
    Msg = emqx_message:set_header(peername, {{127,0,0,1}, 3333}, message()),
    ?assertEqual(undefined, apply_func(clientip, [], #{})),
    ?assertEqual(<<"127.0.0.1">>, apply_func(clientip, [], Msg)).

t_peername(_) ->
    Msg = emqx_message:set_header(peername, {{127,0,0,1}, 3333}, message()),
    ?assertEqual(undefined, apply_func(peername, [], #{})),
    ?assertEqual(<<"127.0.0.1:3333">>, apply_func(peername, [], Msg)).

t_username(_) ->
    Msg = emqx_message:set_header(username, <<"feng">>, message()),
    ?assertEqual(<<"feng">>, apply_func(username, [], Msg)).

t_payload(_) ->
    ?assertEqual(<<"payload">>, apply_func(payload, [], message())),
    NestedMap = #{a => #{b => #{c => c}}},
    ?assertEqual(c, apply_func(payload, [[a,b,c]], NestedMap)).

t_timestamp(_) ->
    Now = emqx_time:now_ms(),
    timer:sleep(100),
    ?assert(Now < apply_func(timestamp, [], message())).

%%------------------------------------------------------------------------------
%% Props
%%------------------------------------------------------------------------------

t_arith_op(_) ->
    ?assert(proper:quickcheck(prop_arith_op())).

prop_arith_op() ->
    ?FORALL({X, Y}, {number(), number()},
            begin
                (X + Y) == apply_func('+', [X, Y]) andalso
                (X - Y) == apply_func('-', [X, Y]) andalso
                (X * Y) == apply_func('*', [X, Y]) andalso
                (if Y =/= 0 ->
                        (X / Y) == apply_func('/', [X, Y]);
                    true -> true
                 end) andalso
                (case is_integer(X)
                     andalso is_integer(Y)
                        andalso Y > 0 of
                     true ->
                         (X rem Y) == apply_func('mod', [X, Y]);
                     false -> true
                end)
            end).

%%------------------------------------------------------------------------------
%% Utility functions
%%------------------------------------------------------------------------------

apply_func(Name, Args) when is_atom(Name) ->
    erlang:apply(emqx_rule_funcs, Name, Args);
apply_func(Fun, Args) when is_function(Fun) ->
    erlang:apply(Fun, Args).

apply_func(Name, Args, Input) when is_map(Input) ->
    apply_func(apply_func(Name, Args), [Input]);
apply_func(Name, Args, Msg) ->
    apply_func(Name, Args, emqx_message:to_map(Msg)).

message() ->
    emqx_message:make(<<"clientid">>, 1, <<"topic/#">>, <<"payload">>).

%%------------------------------------------------------------------------------
%% CT functions
%%------------------------------------------------------------------------------

all() ->
    IsTestCase = fun("t_" ++ _) -> true; (_) -> false end,
    [F || {F, _A} <- module_info(exports), IsTestCase(atom_to_list(F))].

suite() ->
    [{ct_hooks, [cth_surefire]}, {timetrap, {seconds, 30}}].

