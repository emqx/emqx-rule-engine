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

-define(APP, emqx_rule_engine).

-type(maybe(T) :: T | undefined).

-type(rule_id() :: binary()).
-type(rule_name() :: binary()).

-type(resource_id() :: binary()).
-type(action_instance_id() :: binary()).

-type(action_name() :: atom()).
-type(resource_type_name() :: atom()).

-type(descr() :: #{en := binary(), zh => binary()}).

-type(mf() :: {Module::atom(), Fun::atom()}).

-type(hook() :: atom() | 'any').

-define(descr, #{en => <<>>, zh => <<>>}).

-record(action,
        { name :: action_name()
        , for :: hook()
        , app :: atom()
        , types = [] :: list(resource_type_name())
        , module :: module()
        , on_create :: mf()
        , on_destroy :: maybe(mf())
        , params_spec :: #{atom() => term()} %% params specs
        , title = ?descr :: descr()
        , description = ?descr :: descr()
        }).

-record(action_instance,
        { id :: action_instance_id()
        , name :: action_name()
        , args :: #{atom() => term()} %% the args got from API for initializing action_instance
        }).

-record(rule,
        { id :: rule_id()
        , for :: hook()
        , rawsql :: binary()
        , selects :: list()
        , conditions :: tuple()
        , actions :: list(#action_instance{})
        , enabled :: boolean()
        , description :: binary()
        }).

-record(resource,
        { id :: resource_id()
        , type :: resource_type_name()
        , config :: #{} %% the configs got from API for initializing resource
        , description :: binary()
        }).

-record(resource_type,
        { name :: resource_type_name()
        , provider :: atom()
        , params_spec :: #{atom() => term()} %% params specs
        , on_create :: mf()
        , on_destroy :: mf()
        , title = ?descr :: descr()
        , description = ?descr :: descr()
        }).

-record(rule_hooks,
        { hook :: atom()
        , rule_id :: rule_id()
        }).

-record(resource_params,
        { id :: resource_id()
        , params :: #{} %% the params got after initializing the resource
        }).

-record(action_instance_params,
        { id :: action_instance_id()
        , params :: #{} %% the params got after initializing the action
        , apply :: fun((Data::map(), Envs::map()) -> any()) %% the func got after initializing the action
        }).

%% Arithmetic operators
-define(is_arith(Op), (Op =:= '+' orelse
                       Op =:= '-' orelse
                       Op =:= '*' orelse
                       Op =:= '/' orelse
                       Op =:= 'div')).

%% Compare operators
-define(is_comp(Op), (Op =:= '=' orelse
                      Op =:= '=~' orelse
                      Op =:= '>' orelse
                      Op =:= '<' orelse
                      Op =:= '<=' orelse
                      Op =:= '>=' orelse
                      Op =:= '<>' orelse
                      Op =:= '!=')).

%% Logical operators
-define(is_logical(Op), (Op =:= 'and' orelse Op =:= 'or')).

-define(RAISE(_EXP_, _ERROR_),
        begin
            try (_EXP_) catch _:_REASON_ -> throw(_ERROR_) end
        end).
