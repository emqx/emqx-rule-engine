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

-module(emqx_rule_engine_app).

-behaviour(application).

-emqx_plugin(?MODULE).

-export([start/2]).

-export([stop/1]).

-define(APP, emqx_rule_engine).

start(_Type, _Args) ->
    {ok, Sup} = emqx_rule_engine_sup:start_link(),
    ok = emqx_rule_engine:load_providers(),
    ok = emqx_rule_engine:refresh_resources(),
    ok = emqx_rule_engine:refresh_rules(),
    ok = emqx_rule_engine_cli:load(),
    ok = emqx_rule_runtime:start(env()),
    {ok, Sup}.

stop(_State) ->
    ok = emqx_rule_runtime:stop(env()),
    ok = emqx_rule_engine_cli:unload().

env() ->
    maps:from_list(application:get_all_env(?APP)).
