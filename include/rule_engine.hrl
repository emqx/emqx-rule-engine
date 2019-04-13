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

-type(rule_id() :: binary()).
-type(resource_id() :: binary()).

-record(rule,
        { id :: rule_id()
        , name :: binary()
        , for :: atom()
        , rawsql :: binary()
        , topics :: [binary()] | undefined
        , selects :: list()
        , conditions :: tuple()
        , actions :: list()
        , enabled :: boolean()
        , description :: binary()
        }).

-record(action,
        { name :: atom()
        , for :: atom()
        , app :: atom()
        , module :: module()
        , func :: atom()
        , params :: #{atom() => term()}
        , description :: binary()
        }).

-record(resource,
        { id :: resource_id()
        , name :: binary()
        , type :: atom()
        , config :: #{}
        , attrs :: #{}
        , description :: binary()
        }).

-record(resource_instance,
        { id :: {binary(), node()}
        , conns :: list(pid()) | undefined
        , created_at :: erlang:timestamp()
        }).

-record(resource_type,
        { name :: atom()
        , provider :: atom()
        , params :: #{}
        , on_create :: fun((map()) -> map())
        , description :: binary()
        }).

%% Arithmetic operators
-define(is_arith(Op), (Op =:= '+' orelse
                       Op =:= '-' orelse
                       Op =:= '*' orelse
                       Op =:= '/' orelse
                       Op =:= 'div')).

%% Compare operators
-define(is_comp(Op), (Op =:= '=' orelse
                      Op =:= '>' orelse
                      Op =:= '<' orelse
                      Op =:= '<=' orelse
                      Op =:= '>=' orelse
                      Op =:= '<>' orelse
                      Op =:= '!=')).

%% Logical operators
-define(is_logical(Op), (Op =:= 'and' orelse Op =:= 'or')).

