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

%% @doc A Simple SQL Parser for Rule Engine.
%%
%% For example:
%%
%% select topic(2) as deviceId, playload.temperature as temp
%%   from "devices/mydeviceid/events" where temp > 10;
%%
%% Select functions:
%%
%% topic(N)
%% payload(x)(y)
%%
%% Supported Operators in The WHERE Clause:
%%
%% =  Equal
%% <> Not equal. Note: In some versions of SQL this operator may be written as !=
%% >  Greater than
%% <  Less than
%% >= Greater than or equal
%% <= Less than or equal
%% IN To specify multiple possible values for a column
%% AND
%% OR
%% NOT

-module(emqx_rule_sqlparser).

-record(field, {alias, name, func}).

-record(function, {name, params, alias}).

-record(condition, {op, var, val}).

-record(select, {fields, topic, conditions}).

-export([parse/1]).

-spec(parse(string() | binary()) -> #select{}).
parse(Sql) ->
    #select{}.

