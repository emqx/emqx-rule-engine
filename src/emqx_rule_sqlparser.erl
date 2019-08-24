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

-module(emqx_rule_sqlparser).

-include("rule_engine.hrl").
-include("rule_events.hrl").

-export([parse_select/1]).

-export([ select_fields/1
        , select_from/1
        , select_where/1
        ]).

-export([ hook/1
        , unquote/1
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
    try case sqlparse:parsetree(Sql) of
            {ok, [{?SELECT(Fields, From, Where), _Extra}]} ->
                {ok, preprocess(#select{fields = Fields, from = From, where = Where})};
            Error -> Error
        end
    catch
        _Error:Reason ->
            {parse_error, Reason}
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

preprocess(#select{fields = Fields, from = Hooks, where = Conditions}) ->
    Selected = [preprocess_field(Field) || Field <- Fields],
    Froms = [hook(unquote(H)) || H <- Hooks],
    #select{fields = Selected,
            from   = Froms,
            where  = preprocess_condition(Conditions, as_columns(Selected) ++ fixed_columns(Froms))}.

preprocess_field(<<"*">>) ->
    '*';
preprocess_field({'as', Field, Alias}) when is_binary(Alias) ->
    {'as', transform_select_field(Field), transform_alias(Alias)};
preprocess_field(Field) ->
    transform_select_field(Field).

preprocess_condition({Op, L, R}, Columns) when ?is_logical(Op) orelse ?is_comp(Op) ->
    {Op, preprocess_condition(L, Columns), preprocess_condition(R, Columns)};
preprocess_condition({in, Field, {list, Vals}}, Columns) ->
    {in, transform_field(Field, Columns), {list, [transform_field(Val, Columns) || Val <- Vals]}};
preprocess_condition({'not', X}, Columns) ->
    {'not', preprocess_condition(X, Columns)};
preprocess_condition({}, _Columns) ->
    {};
preprocess_condition(Field, Columns) ->
    transform_field(Field, Columns).

transform_field({const, Val}, _Columns) ->
    {const, Val};
transform_field(<<Q, Val/binary>>, _Columns) when Q =:= $'; Q =:= $" ->
    {const, binary:part(Val, {0, byte_size(Val)-1})};
transform_field(Val, Columns) ->
    case is_number_str(Val) of
        true -> {const, Val};
        false ->
            do_transform_field(Val, Columns)
    end.

do_transform_field(<<"payload.", Attr/binary>>, Columns) ->
    validate_var(<<"payload">>, Columns),
    {payload, parse_nested(Attr)};
do_transform_field({Op, Arg1, Arg2}, Columns) when ?is_arith(Op) ->
    {Op, transform_field(Arg1, Columns), transform_field(Arg2, Columns)};
do_transform_field(Var, Columns) when is_binary(Var) ->
    {var, validate_var(escape(parse_nested(Var)), Columns)};
do_transform_field({'fun', Name, Args}, Columns) when is_binary(Name) ->
    Fun = list_to_existing_atom(binary_to_list(Name)),
    {'fun', Fun, [transform_field(Arg, Columns) || Arg <- Args]}.

transform_select_field({const, Val}) ->
    {const, Val};
transform_select_field(<<"payload.", Attr/binary>>) ->
    {payload, parse_nested(Attr)};
transform_select_field({Op, Arg1, Arg2}) when ?is_arith(Op) ->
    {Op, transform_select_field(Arg1), transform_select_field(Arg2)};
transform_select_field(Var) when is_binary(Var) ->
    {var, escape(parse_nested(Var))};
transform_select_field({'fun', Name, Args}) when is_binary(Name) ->
    Fun = list_to_existing_atom(binary_to_list(Name)),
    {'fun', Fun, [transform_select_field(Arg) || Arg <- Args]}.

validate_var(Var, SupportedColumns) ->
    case {Var, lists:member(Var, SupportedColumns)} of
        {_, true} -> escape(Var);
        {[TopVar | _], false} ->
            lists:member(TopVar, SupportedColumns) orelse error({unknown_column, Var}),
            escape(Var);
        {_, false} ->
            error({unknown_column, escape(Var)})
    end.

is_number_str(Str) when is_binary(Str) ->
    try _ = binary_to_integer(Str), true
    catch _:_ ->
        try _ = binary_to_float(Str), true
        catch _:_ -> false
        end
    end;
is_number_str(_NonStr) ->
    false.

as_columns(Selected) ->
    as_columns(Selected, []).
as_columns([], Acc) -> Acc;
as_columns([{as, _, Val} | Selected], Acc) ->
    as_columns(Selected, [Val | Acc]);
as_columns([_ | Selected], Acc) ->
    as_columns(Selected, Acc).

fixed_columns(Columns) when is_list(Columns) ->
    lists:flatten([?COLUMNS(Col) || Col <- Columns]).

transform_alias(Alias) ->
    parse_nested(unquote(Alias)).

parse_nested(Attr) ->
    case string:split(Attr, <<".">>, all) of
        [Attr] -> Attr;
        Nested -> Nested
    end.

%% escape the SQL reserved key words
escape(<<"TIMESTAMP">>) -> <<"timestamp">>;
escape(Var) -> Var.

unquote(Topic) ->
    string:trim(Topic, both, "\"'").

hook(<<"client.connected">>) ->
    'client.connected';
hook(<<"client.disconnected">>) ->
    'client.disconnected';
hook(<<"client.subscribe">>) ->
    'client.subscribe';
hook(<<"client.unsubscribe">>) ->
    'client.unsubscribe';
hook(<<"message.publish">>) ->
    'message.publish';
hook(<<"message.deliver">>) ->
    'message.deliver';
hook(<<"message.acked">>) ->
    'message.acked';
hook(<<"message.dropped">>) ->
    'message.dropped';
hook(_) ->
    error(unknown_event_type).
