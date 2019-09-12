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

-module(emqx_rule_maps).

-export([ nested_get/2
        , nested_put/3
        , get_value/2
        , get_value/3
        , put_value/3
        , atom_key_map/1
        , unsafe_atom_key_map/1
        ]).

nested_get(Key, Map) when not is_list(Key) ->
    get_value(Key, Map);
nested_get([Key], Map) ->
    get_value(Key, Map);
nested_get([Key|More], Map) ->
    case maps:find(Key, Map) of
        {ok, Val} ->
            nested_get(More, Val);
        error -> undefined
    end;
nested_get([], Val) ->
    Val.

nested_put(_, undefined, Map) ->
    Map;
nested_put(Key, Val, Map) when not is_list(Key) ->
    put_value(Key, Val, Map);
nested_put([Key], Val, Map) ->
    put_value(Key, Val, Map);
nested_put([Key|More], Val, Map) ->
    SubMap = maps:get(Key, Map, #{}),
    put_value(Key, nested_put(More, Val, SubMap), Map);
nested_put([], Val, _Map) ->
    Val.

get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_binary(Key) ->
    case maps:find(Key, Map) of
        {ok, Val} -> Val;
        error ->
            try list_to_existing_atom(
                  binary_to_list(Key)) of
                AtomKey ->
                    maps:get(AtomKey, Map, Default)
            catch error:badarg ->
                Default
            end
    end;
get_value(Key, Map, Default) ->
    maps:get(Key, Map, Default).

put_value(_Key, undefined, Map) ->
    Map;
put_value(Key, Val, Map) ->
    maps:put(Key, Val, Map).

atom_key_map(BinKeyMap) when is_map(BinKeyMap) ->
    maps:fold(
        fun(K, V, Acc) when is_binary(K) ->
              Acc#{binary_to_existing_atom(K, utf8) => atom_key_map(V)};
           (K, V, Acc) when is_list(K) ->
              Acc#{list_to_existing_atom(K) => atom_key_map(V)};
           (K, V, Acc) when is_atom(K) ->
              Acc#{K => atom_key_map(V)}
        end, #{}, BinKeyMap);
atom_key_map(ListV) when is_list(ListV) ->
    [atom_key_map(V) || V <- ListV];
atom_key_map(Val) -> Val.

unsafe_atom_key_map(BinKeyMap) when is_map(BinKeyMap) ->
    maps:fold(
        fun(K, V, Acc) when is_binary(K) ->
              Acc#{binary_to_atom(K, utf8) => unsafe_atom_key_map(V)};
           (K, V, Acc) when is_list(K) ->
              Acc#{list_to_atom(K) => unsafe_atom_key_map(V)};
           (K, V, Acc) when is_atom(K) ->
              Acc#{K => unsafe_atom_key_map(V)}
        end, #{}, BinKeyMap);
unsafe_atom_key_map(ListV) when is_list(ListV) ->
    [unsafe_atom_key_map(V) || V <- ListV];
unsafe_atom_key_map(Val) -> Val.
