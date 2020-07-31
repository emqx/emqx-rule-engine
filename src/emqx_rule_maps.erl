%%--------------------------------------------------------------------
%% Copyright (c) 2020 EMQ Technologies Co., Ltd. All Rights Reserved.
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
        , nested_get/3
        , nested_put/3
        , put_value/3
        , atom_key_map/1
        , unsafe_atom_key_map/1
        ]).

nested_get(Key, Data) ->
    nested_get(Key, Data, undefined).
nested_get(Key, Data, Default) when is_binary(Data) ->
    try emqx_json:decode(Data, [return_maps]) of
        Json -> nested_get(Key, Json, Default)
    catch
        _:_ -> Default
    end;
nested_get({var, Key}, Data, Default) ->
    general_map_get({key, Key}, Data, Data, Default);
nested_get({path, Path}, Data, Default) when is_list(Path) ->
    do_nested_get(Path, Data, Data, Default).

do_nested_get([Key], Data, OrgData, Default) ->
    general_map_get(Key, Data, OrgData, Default);
do_nested_get([Key|More], Data, OrgData, Default) ->
    case general_map_get(Key, Data, OrgData, undefined) of
        undefined -> Default;
        Val -> do_nested_get(More, Val, OrgData, Default)
    end;
do_nested_get([], Val, _OrgData, _Default) ->
    Val.

nested_put(Key, Val, Map) when not is_map(Map) ->
    nested_put(Key, Val, #{});
nested_put(_, undefined, Map) ->
    Map;
nested_put(Key, Val, Map) when not is_list(Key) ->
    put_value(Key, Val, Map);
nested_put([Key], Val, Map) ->
    put_value(Key, Val, Map);
nested_put([Key|More], Val, Map) ->
    SubMap = general_map_get(Key, Map, Map, #{}),
    put_value(Key, nested_put(More, Val, SubMap), Map);
nested_put([], Val, _Map) ->
    Val.

put_value(_Key, undefined, Map) ->
    Map;
put_value(Key, Val, Map) ->
    general_map_put(Key, Val, Map).

general_map_get(Key, Map, OrgData, Default) ->
    general_map(Key, Map, OrgData,
        fun
            ({equivalent, {_EquiKey, Val}}) -> Val;
            ({found, {_Key, Val}}) -> Val;
            (not_found) -> Default
        end).

general_map_put(Key, Val, Map) ->
    general_map(Key, Map, #{},
        fun
            ({equivalent, {EquiKey, _Val}}) -> maps:put(EquiKey, Val, Map);
            (_) -> maps:put(Key, Val, Map)
        end).

general_map({key, Key}, Map, _OrgData, Handler) when is_map(Map) ->
    case maps:find(Key, Map) of
        {ok, Val} -> Handler({found, {Key, Val}});
        error when is_atom(Key) ->
            %% the map may have an equivalent binary-form key
            BinKey = emqx_rule_utils:bin(Key),
            case maps:find(BinKey, Map) of
                {ok, Val} -> Handler({equivalent, {BinKey, Val}});
                error -> Handler(not_found)
            end;
        error when is_binary(Key) ->
            try %% the map may have an equivalent atom-form key
                AtomKey = list_to_existing_atom(binary_to_list(Key)),
                case maps:find(AtomKey, Map) of
                    {ok, Val} -> Handler({equivalent, {AtomKey, Val}});
                    error -> Handler(not_found)
                end
            catch error:badarg ->
                Handler(not_found)
            end;
        error ->
            Handler(not_found)
    end;
general_map({key, _Key}, _Map, _OrgData, Handler) ->
    Handler(not_found);
general_map({index, {const, Index}}, List, _OrgData, Handler) when is_list(List) ->
    Val = lists:nth(Index, List),
    Handler({found, {Index, Val}});
general_map({index, Index}, List, OrgData, Handler) when is_list(List) ->
    Index0 = nested_get(Index, OrgData),
    Val = lists:nth(Index0, List),
    Handler({found, {Index, Val}});
general_map({index, _}, List, _OrgData, Handler) when not is_list(List) ->
    Handler(not_found).

%%%-------------------------------------------------------------------
%%% atom key map
%%%-------------------------------------------------------------------
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