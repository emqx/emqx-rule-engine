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

-export([parse_select/1]).

-export([ select_fields/1
        , select_from/1
        , select_where/1
        ]).

-record(select, {fields, from, where}).

-opaque(select() :: #select{}).

-export_type([select/0]).

-spec(parse_select(string()|binary())
      -> {ok, select()} | {parse_error, term()} | {lex_error, term()}).
parse_select(Sql) ->
    case sqlparse:parsetree(Sql) of
        {ok, ParseTree} ->
            {ok, hd([#select{fields = Fields, from = From, where = Where}
                     || {{select, [{fields, Fields}, {from, From}, {where, Where}|_]}, _Extra}
                        <- ParseTree])};
        Error -> Error
    end.

select_fields(#select{fields = Fields}) ->
    Fields.

select_from(#select{from = From}) ->
    From.

select_where(#select{where = Where}) ->
    Where.

