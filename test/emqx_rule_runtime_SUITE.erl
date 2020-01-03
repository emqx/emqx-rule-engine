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

-module(emqx_rule_runtime_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").

all() -> emqx_ct:all(?MODULE).

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, Config) ->
    Config.


% t_on_message_acked(_) ->
%     error('TODO').

% t_on_message_deliver(_) ->
%     error('TODO').

% t_on_message_dropped(_) ->
%     error('TODO').

% t_on_message_publish(_) ->
%     error('TODO').

% t_on_client_unsubscribe(_) ->
%     error('TODO').

% t_on_client_subscribe(_) ->
%     error('TODO').

% t_on_client_disconnected(_) ->
%     error('TODO').

% t_on_client_connected(_) ->
%     error('TODO').

% t_stop(_) ->
%     error('TODO').

% t_start(_) ->
%     error('TODO').

% t_apply_rule(_) ->
%     error('TODO').

