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

-module(emqx_rule_validator).

-include("rule_engine.hrl").

-export([ validate_params/2
        , validate_spec/1
        ]).

-type(params_spec() :: map()).
-type(params() :: map()).

-define(BASIC_DATA_TYPES, [string, number, float, enum]).

%%------------------------------------------------------------------------------
%% APIs
%%------------------------------------------------------------------------------

%% Validate the params according the spec and return a new spec.
%% Note that this function will throw out exceptions in case of
%% validation failure.
-spec(validate_params(params(), params_spec()) -> params()).
validate_params(Params, ParamsSepc) ->
    maps:map(fun(Name, Spec) ->
            do_validate_param(Name, Spec, Params)
        end, ParamsSepc),
    ok.

-spec(validate_spec(params_spec()) -> ok).
validate_spec(ParamsSepc) ->
    maps:map(fun do_validate_spec/2, ParamsSepc),
    ok.

%%------------------------------------------------------------------------------
%% Internal Functions
%%------------------------------------------------------------------------------

do_validate_param(Name, Spec = #{required := true}, Params) ->
    with_fields(Name, Params,
        fun (not_found) -> error({required_field_missing, Name});
            (Val) -> do_validate_param(Val, Spec)
        end);
do_validate_param(Name, Spec, Params) ->
    with_fields(Name, Params,
        fun (not_found) -> ok; %% optional field 'Name'
            (Val) -> do_validate_param(Val, Spec)
        end).

do_validate_param(Val, Spec = #{type := Type}) ->
    case maps:find(enum, Spec) of
        {ok, Enum} -> validate_enum(Val, Enum);
        error -> ok
    end,
    validate_type(Val, Type, Spec).

validate_type(Val, string, Spec) ->
    ok = validate_string(Val, reg_exp(maps:get(format, Spec, any)));
validate_type(Val, number, Spec) ->
    ok = validate_number(Val, maps:get(range, Spec, any));
validate_type(Val, boolean, _Spec) ->
    ok = validate_boolean(Val);
validate_type(Val, array, Spec) ->
    [do_validate_param(V, maps:get(items, Spec)) || V <- Val],
    ok;
validate_type(Val, object, Spec) ->
    ok = validate_object(Val, maps:get(schema, Spec, any)).

validate_enum(Val, Enum) ->
    case lists:member(Val, Enum) of
        true -> ok;
        false -> error({invalid_data_type, {enum, {Val, Enum}}})
    end.

validate_string(Val, RegExp) ->
    try re:run(Val, RegExp) of
        nomatch -> error({invalid_data_type, {string, Val}});
        _Match -> ok
    catch
        _:_ -> error({invalid_data_type, {string, Val}})
    end.

validate_number(Val, any) when is_integer(Val); is_float(Val) ->
    ok;
validate_number(Val, _Range = [Min, Max])
        when (is_integer(Val) orelse is_float(Val)),
             (Val >= Min andalso Val =< Max) ->
    ok;
validate_number(Val, Range) ->
    error({invalid_data_type, {number, {Val, Range}}}).

validate_object(Val, Schema) ->
    validate_params(Val, Schema).

validate_boolean(true) -> ok;
validate_boolean(false) -> ok;
validate_boolean(Val) -> error({invalid_data_type, {boolean, Val}}).

reg_exp(url) -> "^https?://\\w+(\.\\w+)*(:[0-9]+)?";
reg_exp(topic) -> "^/?(\\w|\\#|\\+)+(/(\\w|\\#|\\+))*$";
reg_exp(resource_type) -> "[a-zA-Z0-9_:-]";
reg_exp(any) -> ".*";
reg_exp(RegExp) -> RegExp.

do_validate_spec(Name, Spec = #{type := object}) ->
    with_fields(schema, Spec,
        fun (not_found) -> error({required_field_missing, {schema, Name}});
            (Schema) -> validate_spec(Schema)
        end);
do_validate_spec(Name, Spec = #{type := array}) ->
    with_fields(items, Spec,
        fun (not_found) -> error({required_field_missing, {items, Name}});
            (Items) -> do_validate_spec(Name, Items)
        end);
do_validate_spec(Name, Spec = #{type := Type}) ->
    ok = supported_data_type(Type, ?BASIC_DATA_TYPES),
    ok = validate_default_value(Name, Spec),
    ok.

supported_data_type(Type, Supported) ->
    case lists:member(Type, Supported) of
        false -> error({unsupported_data_types, Type});
        true -> ok
    end.

validate_default_value(Name, Spec) ->
    case maps:get(required, Spec, false) of
        true -> ok;
        false ->
            with_fields(default, Spec,
                fun (not_found) -> error({required_field_missing, {default, Name}});
                    (_Default) -> ok
                end)
    end.

with_fields(Field, Spec, Func) ->
    case maps:find(Field, Spec) of
        {ok, Value} -> Func(Value);
        error -> Func(not_found)
    end.
