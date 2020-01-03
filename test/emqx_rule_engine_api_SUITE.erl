%%--------------------------------------------------------------------
%% Copyright (c) 2020 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(emqx_rule_engine_api_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").

all() -> emqx_ct:all(?MODULE).

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, Config) ->
    Config.

% t_create_rule(_) ->
%     error('TODO').

% t_list_rules(_) ->
%     error('TODO').

% t_show_rule(_) ->
%     error('TODO').

% t_delete_rule(_) ->
%     error('TODO').

% t_list_actions(_) ->
%     error('TODO').

% t_show_action(_) ->
%     error('TODO').

% t_create_resource(_) ->
%     error('TODO').

% t_list_resources(_) ->
%     error('TODO').

% t_list_resources_by_type(_) ->
%     error('TODO').

% t_show_resource(_) ->
%     error('TODO').

% t_get_resource_status(_) ->
%     error('TODO').

% t_start_resource(_) ->
%     error('TODO').

% t_delete_resource(_) ->
%     error('TODO').

% t_list_resource_types(_) ->
%     error('TODO').

% t_show_resource_type(_) ->
%     error('TODO').

% t_list_events(_) ->
%     error('TODO').
