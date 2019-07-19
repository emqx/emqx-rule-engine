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
        , unsafe_atom_key/1
        ]).

%% connectivity check
-export([ http_connectivity/1,
          tcp_connectivity/2
        ]).

-define(EX_PLACE_HOLDER, "(\\$\\{[a-zA-Z0-9\\._]+\\})").

-type(uri_string() :: iodata()).

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
        [{var, fun(Data) -> bin(get_phld_var(Phld, Data)) end},
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
                [sql_data(get_phld_var(Phld, Data))
                 || Phld <- [hd(PH) || PH <- PlaceHolders]]
             end};
        nomatch ->
            {Sql, fun(_) -> [] end}
    end.

get_phld_var(Phld, Data) ->
    emqx_rule_maps:nested_get(atom_key(parse_nested(unwrap(Phld))), Data).

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

unsafe_atom_key(Key) when is_atom(Key) ->
    Key;
unsafe_atom_key(_Keys = [Key | SubKeys]) when is_binary(Key) ->
    [binary_to_atom(Key, utf8) | SubKeys];
unsafe_atom_key(Key) when is_binary(Key) ->
    binary_to_atom(Key, utf8).

atom_key(Key) when is_atom(Key) ->
    Key;
atom_key(Keys = [Key | SubKeys]) when is_binary(Key) -> %% nested keys
    try [binary_to_existing_atom(Key, utf8) | SubKeys]
    catch error:badarg -> error({invalid_key, Keys})
    end;
atom_key(Key) when is_binary(Key) ->
    try binary_to_existing_atom(Key, utf8)
    catch error:badarg -> error({invalid_key, Key})
    end.

-spec(http_connectivity(uri_string()) -> ok | {error, Reason :: term()}).
http_connectivity(Url) ->
    case uri_string:parse(uri_string:normalize(Url)) of
        {error, Reason, _} ->
            {error, Reason};
        #{host := Host, port := Port} ->
            tcp_connectivity(str(Host), Port);
        #{host := Host, scheme := Scheme} ->
            tcp_connectivity(str(Host), default_port(Scheme));
        _ ->
            {error, {invalid_url, Url}}
    end.

-spec(tcp_connectivity(Host :: inet:socket_address() | inet:hostname(),
                       Port :: inet:port_number())
        -> ok | {error, Reason :: term()}).
tcp_connectivity(Host, Port) ->
    case gen_tcp:connect(Host, Port, [], 3000) of
        {ok, Sock} -> gen_tcp:close(Sock), ok;
        {error, Reason} -> {error, Reason}
    end.

default_port(http) -> 80;
default_port(https) -> 443.

unwrap(<<"${", Val/binary>>) ->
    binary:part(Val, {0, byte_size(Val)-1}).

str(List) when is_list(List) -> List;
str(Bin) when is_binary(Bin) -> binary_to_list(Bin);
str(Atom) when is_atom(Atom) -> atom_to_list(Atom).

bin(List) when is_list(List) -> list_to_binary(List);
bin(Bin) when is_binary(Bin) -> Bin;
bin(Num) when is_number(Num) -> number_to_binary(Num);
bin(Atom) when is_atom(Atom) -> atom_to_binary(Atom, utf8);
bin(Map) when is_map(Map) -> jsx:encode(Map).

sql_data(List) when is_list(List) -> List;
sql_data(Bin) when is_binary(Bin) -> Bin;
sql_data(Num) when is_number(Num) -> Num;
sql_data(Bool) when is_boolean(Bool) -> Bool;
sql_data(Atom) when is_atom(Atom) -> atom_to_binary(Atom, utf8);
sql_data(Map) when is_map(Map) -> jsx:encode(Map).

number_to_binary(Int) when is_integer(Int) ->
    integer_to_binary(Int);
number_to_binary(Float) when is_float(Float) ->
    float_to_binary(Float).

utf8_bin(Str) ->
    unicode:characters_to_binary(Str).
utf8_str(Str) ->
    unicode:characters_to_list(Str).

parse_nested(Attr) ->
    case string:split(Attr, <<".">>, all) of
        [Attr] -> Attr;
        Nested -> Nested
    end.
