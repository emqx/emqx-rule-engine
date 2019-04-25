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

-module(emqx_rule_sqlparser).

-include("rule_engine.hrl").

-export([parse_select/1]).

-export([ select_fields/1
        , select_from/1
        , select_where/1
        ]).

-record(select, {fields, from, where}).

-opaque(select() :: #select{}).

-type(const() :: {const, number()|binary()}).

-type(variable() :: binary() | list(binary())).

-type(alias() :: binary() | list(binary())).

-type(field() :: const() | variable()
               | {as, field(), alias()}
               | {'fun', atom(), list(field())}).

-export_type([select/0]).

-define(SELECT(Fields, From, Where),
        {select, [{fields, Fields}, {from, From}, {where, Where}|_]}).

%% Parse one select statement.
-spec(parse_select(string() | binary())
      -> {ok, select()} | {parse_error, term()} | {lex_error, term()}).
parse_select(Sql) ->
    case sqlparse:parsetree(Sql) of
        {ok, [{?SELECT(Fields, From, Where), _Extra}]} ->
            {ok, preprocess(#select{fields = Fields, from = From, where = Where})};
        Error -> Error
    end.

-spec(select_fields(select()) -> list(field())).
select_fields(#select{fields = Fields}) ->
    Fields.

-spec(select_from(select()) -> list(binary())).
select_from(#select{from = From}) ->
    From.

-spec(select_where(select()) -> tuple()).
select_where(#select{where = Where}) ->
    Where.

preprocess(#select{fields = Fields, from = Topics, where = Conditions}) ->
    Selected = [preprocess_field(Field) || Field <- Fields],
    #select{fields = Selected,
            from   = [unquote(Topic) || Topic <- Topics],
            where  = preprocess_condition(Conditions, Selected)}.

preprocess_field(<<"*">>) ->
    '*';
preprocess_field({'as', Field, Alias}) when is_binary(Alias) ->
    {'as', transform_non_const_field(Field), transform_alias(Alias)};
preprocess_field(Field) ->
    transform_non_const_field(Field).

preprocess_condition({Op, L, R}, Selected) when ?is_logical(Op) orelse ?is_comp(Op) ->
    {Op, preprocess_condition(L, Selected), preprocess_condition(R, Selected)};
preprocess_condition({in, Field, {list, Vals}}, Selected) ->
    {in, transform_field(Field, Selected), {list, [transform_field(Val, Selected) || Val <- Vals]}};
preprocess_condition({'not', X}, Selected) ->
    {'not', preprocess_condition(X, Selected)};
preprocess_condition({}, _Selected) ->
    {};
preprocess_condition(Field, Selected) ->
    transform_field(Field, Selected).

transform_field({const, Val}, _Selected) ->
    {const, Val};
transform_field(<<Q, Val/binary>>, _Selected) when Q =:= $'; Q =:= $" ->
    {const, binary:part(Val, {0, byte_size(Val)-1})};
transform_field(Val, Selected) ->
    case is_selected_field(Val, Selected) of
        false -> {const, Val};
        true -> do_transform_field(Val, Selected)
    end.
do_transform_field(<<"payload.", Attr/binary>>, _Selected) ->
    {payload, parse_nested(Attr)};
do_transform_field({Op, Arg1, Arg2}, Selected) when ?is_arith(Op) ->
    {Op, transform_field(Arg1, Selected), transform_field(Arg2, Selected)};
do_transform_field(Var, _Selected) when is_binary(Var) ->
    {var, parse_nested(Var)};
do_transform_field({'fun', Name, Args}, Selected) when is_binary(Name) ->
    Fun = list_to_existing_atom(binary_to_list(Name)),
    {'fun', Fun, [transform_field(Arg, Selected) || Arg <- Args]}.

transform_non_const_field(<<"payload.", Attr/binary>>) ->
    {payload, parse_nested(Attr)};
transform_non_const_field({Op, Arg1, Arg2}) when ?is_arith(Op) ->
    {Op, transform_non_const_field(Arg1), transform_non_const_field(Arg2)};
transform_non_const_field(Var) when is_binary(Var) ->
    {var, parse_nested(Var)};
transform_non_const_field({'fun', Name, Args}) when is_binary(Name) ->
    Fun = list_to_existing_atom(binary_to_list(Name)),
    {'fun', Fun, [transform_non_const_field(Arg) || Arg <- Args]}.

is_selected_field(_Val, []) ->
    false;
is_selected_field(_Val, ['*' | _Selected]) ->
    true;
is_selected_field(Val, [{as, _, Val} | _Selected]) ->
    true;
is_selected_field(Val, [{payload, Val} | _Selected]) ->
    true;
is_selected_field(Val, [{payload, Nested} | _Selected]) when is_list(Nested) ->
    NestedFields = join_str(Nested, <<".">>),
    Val =:= <<"payload.", NestedFields/binary>>;
is_selected_field(Val, [{var, Val} | _Selected]) ->
    true;
is_selected_field(Val, [{var, Nested} | _Selected]) when is_list(Nested) ->
    Val =:= join_str(Nested, <<".">>);
is_selected_field(Val, [_ | Selected]) ->
    is_selected_field(Val, Selected).

transform_alias(Alias) ->
    parse_nested(unquote(Alias)).

parse_nested(Attr) ->
    case string:split(Attr, <<".">>, all) of
        [Attr] -> Attr;
        Nested -> Nested
    end.

unquote(Topic) ->
    string:trim(Topic, both, "\"'").

join_str([], _Delim) ->
    <<>>;
join_str([F | Fields], Delim) ->
    join_str(Fields, Delim, F).

join_str([], _Delim, Joined) ->
    Joined;
join_str([F | Fields], Delim, Joined) ->
    join_str(Fields, Delim, <<Joined/binary, Delim/binary, F/binary>>).
