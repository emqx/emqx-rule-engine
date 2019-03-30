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

select_fields(#select{fields = Fields}) ->
    Fields.

select_from(#select{from = From}) ->
    From.

select_where(#select{where = Where}) ->
    Where.

preprocess(#select{fields = Fields, from = Topics, where = Conditions}) ->
    #select{fields = [preprocess_field(Field) || Field <- Fields],
            from   = [unquote(Topic) || Topic <- Topics],
            where  = preprocess_condition(Conditions)}.

preprocess_field(<<"*">>) ->
    '*';
preprocess_field({'as', Field, Alias}) when is_binary(Alias) ->
    {'as', transform_field(Field), transform_alias(Alias)};
preprocess_field(Field) ->
    transform_field(Field).

preprocess_condition({Op, L, R}) when ?is_logical(Op) orelse ?is_comp(Op) ->
    {Op, preprocess_condition(L), preprocess_condition(R)};
preprocess_condition({in, Field, {list, Vals}}) ->
    {in, transform_field(Field), {list, [transform_field(Val) || Val <- Vals]}};
preprocess_condition({'not', X}) ->
    {'not', preprocess_condition(X)};
preprocess_condition({}) ->
    {};
preprocess_condition(Field) ->
    transform_field(Field).

transform_field({const, Val}) when is_number(Val); is_binary(Val) ->
    {const, Val};
transform_field(<<"payload.", Attr/binary>>) ->
    {payload, parse_nested(Attr)};
transform_field(Var) when is_binary(Var) ->
    {var, parse_nested(unquote(Var))};
transform_field({Op, Arg1, Arg2}) when ?is_arith(Op) ->
    {Op, transform_field(Arg1), transform_field(Arg2)};
transform_field({'fun', Name, Args}) when is_binary(Name) ->
    Fun = list_to_existing_atom(binary_to_list(Name)),
    {'fun', Fun, [transform_field(Arg) || Arg <- Args]}.

transform_alias(Alias) ->
    parse_nested(unquote(Alias)).

parse_nested(Attr) ->
    string:split(Attr, <<".">>, all).

unquote(Topic) ->
    string:trim(Topic, both, "\"").

