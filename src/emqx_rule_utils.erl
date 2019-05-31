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

-module(emqx_rule_utils).

%% preprocess and process tempalte string with place holders
-export([ preproc_tmpl/1
        , proc_tmpl/2
        , preproc_sql/1
        , preproc_sql/2]).

%% type converting
-export([ str/1
        , bin/1
        , utf8_bin/1
        , utf8_str/1
        , number_to_binary/1
        , atom_key/1
        ]).

-define(EX_PLACE_HOLDER, "(\\$\\{[a-zA-Z0-9\\._]+\\})").

-type(tmpl_token() :: list({var, fun()} | {str, binary()})).

-type(prepare_statement() :: binary()).

-type(prepare_params() :: fun((binary()) -> list())).

%% preprocess template string with place holders
-spec(preproc_tmpl(binary()) -> tmpl_token()).
preproc_tmpl(Str) ->
    Tokens = re:split(Str, ?EX_PLACE_HOLDER, [{return,binary},group]),
    preproc_tmpl(Tokens, []).

preproc_tmpl([], Acc) ->
    lists:reverse(Acc);
preproc_tmpl([[Tkn, Phld]| Tokens], Acc) ->
    preproc_tmpl(Tokens,
        [{var, fun(Data) -> bin(maps:get(atom_key(var(Phld)), Data, undefined)) end},
         {str, Tkn} | Acc]);
preproc_tmpl([[Tkn]| Tokens], Acc) ->
    preproc_tmpl(Tokens, [{str, Tkn} | Acc]).

-spec(proc_tmpl(tmpl_token(), binary()) -> binary()).
proc_tmpl(Tokens, Data) ->
    list_to_binary(
        lists:map(
            fun ({str, Tkn}) -> Tkn;
                ({var, GetVal}) -> GetVal(Data)
            end, Tokens)).

%% preprocess SQL with place holders
-spec(preproc_sql(Sql::binary()) -> {prepare_statement(), prepare_params()}).
preproc_sql(Sql) ->
    preproc_sql(Sql, '?').

-spec(preproc_sql(Sql::binary(), ReplaceWith :: '?' | '$n') -> {prepare_statement(), prepare_params()}).
preproc_sql(Sql, ReplaceWith) ->
    case re:run(Sql, ?EX_PLACE_HOLDER, [{capture, all_but_first, binary}, global]) of
        {match, PlaceHolders} ->
            {repalce_with(Sql, ReplaceWith),
             fun(Data) ->
                [maps:get(atom_key(Key), Data, undefined)
                 || Key <- [var(hd(PH)) || PH <- PlaceHolders]]
             end};
        nomatch ->
            {Sql, fun(_) -> [] end}
    end.

repalce_with(Tmpl, '?') ->
    re:replace(Tmpl, ?EX_PLACE_HOLDER, "?", [{return, binary}, global]);
repalce_with(Tmpl, '$n') ->
    Parts = re:split(Tmpl, ?EX_PLACE_HOLDER, [{return, binary}, trim, group]),
    {Res, _} =
        lists:foldl(
            fun([Tkn, _Phld], {Acc, Seq}) ->
                    Seq1 = erlang:integer_to_binary(Seq),
                    {<<Acc/binary, Tkn/binary, "$", Seq1/binary>>, Seq + 1};
                ([Tkn], {Acc, Seq}) ->
                    {<<Acc/binary, Tkn/binary>>, Seq}
            end, {<<>>, 1}, Parts),
    Res.

atom_key(Key) when is_atom(Key) ->
    Key;
atom_key(Key) when is_list(Key) ->
    try list_to_existing_atom(Key)
    catch error:badarg -> error({invalid_key, Key})
    end;
atom_key(Key) when is_binary(Key) ->
    try binary_to_existing_atom(Key, utf8)
    catch error:badarg -> error({invalid_key, Key})
    end.

var(<<"${", Val/binary>>) ->
    binary:part(Val, {0, byte_size(Val)-1}).

str(List) when is_list(List) -> List;
str(Bin) when is_binary(Bin) -> binary_to_list(Bin);
str(Atom) when is_atom(Atom) -> atom_to_list(Atom).

bin(List) when is_list(List) -> list_to_binary(List);
bin(Bin) when is_binary(Bin) -> Bin;
bin(Num) when is_number(Num) -> number_to_binary(Num);
bin(Atom) when is_atom(Atom) -> atom_to_binary(Atom, utf8).

number_to_binary(Int) when is_integer(Int) ->
    integer_to_binary(Int);
number_to_binary(Float) when is_float(Float) ->
    float_to_binary(Float).

utf8_bin(Str) ->
    unicode:characters_to_binary(Str).
utf8_str(Str) ->
    unicode:characters_to_list(Str).
