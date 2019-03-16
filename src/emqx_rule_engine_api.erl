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

-module(emqx_rule_engine_api).

-rest_api(#{name   => create_rule,
            method => 'POST',
            path   => "/rules/",
            func   => create_rule,
            descr  => "Create a rule"}).

-rest_api(#{name   => list_rules,
            method => 'GET',
            path   => "/rules/",
            func   => list_rules,
            descr  => "A list of all rules"}).

-rest_api(#{name   => show_rule,
            method => 'GET',
            path   => "/rules/:bin:id",
            func   => show_rule,
            descr  => "Show a rule"}).

-rest_api(#{name   => list_actions,
            method => 'GET',
            path   => "/actions/",
            func   => list_actions,
            descr  => "A list of all actions"}).

-rest_api(#{name   => show_action,
            method => 'GET',
            path   => "/actions/:bin:id",
            func   => show_action,
            descr  => "Show an action"}).

-rest_api(#{name   => list_resources,
            method => 'GET',
            path   => "/resources/",
            func   => list_resources,
            descr  => "A list of all resources"}).

-rest_api(#{name   => show_resource,
            method => 'GET',
            path   => "/resources/:bin:id",
            func   => show_resource,
            descr  => "Show a resource"}).

-export([create_rule/2,
         list_rules/2,
         show_rule/2,
         delete_rule/2
        ]).

-export([list_actions/2,
         show_action/2
        ]).

-export([list_resources/2,
         show_resource/2
        ]).

%%------------------------------------------------------------------------------
%% Rules API
%%------------------------------------------------------------------------------

create_rule(_Bindings, Params) ->
    %% TODO: Create a rule
    emqx_mgmt:return({ok, Params}).

list_rules(_Bindings, _Params) ->
    %% TODO: List all rules
    emqx_mgmt:return({ok, []}).

show_rule(#{id := _Id}, _Params) ->
    %% TODO:
    emqx_mgmt:return({ok, #{}}).

delete_rule(#{id := _Id}, _Params) ->
    %% TODO:
    emqx_mgmt:return().

%%------------------------------------------------------------------------------
%% Actions API
%%------------------------------------------------------------------------------

list_actions(_Bindings, _Params) ->
    %% TODO:
    emqx_mgmt:return({ok, []}).

show_action(#{id := _Id}, _Params) ->
    %% TODO:
    emqx_mgmt:return({ok, #{}}).

%%------------------------------------------------------------------------------
%% Resources API
%%------------------------------------------------------------------------------

list_resources(_Bindings, _Params) ->
    %% TODO:
    emqx_mgmt:return({ok, []}).

show_resource(#{id := _Id}, _Params) ->
    %% TODO:
    emqx_mgmt:return({ok, #{}}).


