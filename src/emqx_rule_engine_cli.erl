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

-module(emqx_rule_engine_cli).

-export([load/0,
         commands/0,
         unload/0
        ]).

-export([rules/1,
         actions/1,
         resources/1
        ]).

%%-----------------------------------------------------------------------------
%% Load/Unload Commands
%%-----------------------------------------------------------------------------

-spec(load() -> ok).
load() ->
    lists:foreach(fun(Cmd) ->
                          emqx_ctl:register_command(Cmd, {?MODULE, Cmd}, [])
                  end, commands()).

-spec(commands() -> list(atom()).
commands() ->
    [rules, 'rule-actions', resources].

-spec(unload() -> ok).
unload() ->
    lists:foreach(fun emqx_ctl:unregister_command/1, commands()).

%%-----------------------------------------------------------------------------
%% 'rules' command
%%-----------------------------------------------------------------------------

rules(["list"]) ->
    %% TODO:
    emqx_cli:print("TODO: list rules...~n");

rules(["show", RuleId]) ->
    %% TODO:
    emqx_cli:print("TODO: show rule - ~s~n", [RuleId]);

rules(_usage) ->
    emqx_cli:usage([{"rules list",          "List all rules"},
                    {"rules show <RuleId>", "Show a rule"}
                   ]).

%%-----------------------------------------------------------------------------
%% 'rule-actions' command
%%-----------------------------------------------------------------------------

'rule-actions'(["list"]) ->
    emqx_cli:print("TODO: list rule-actions...~n");

'rule-actions'(["show", ActionId]) ->
    emqx_cli:print("TODO: show rule-action - ~s~n", [ActionId]);

'rule-actions'(_usage) ->
    emqx_cli:usage([{"rule-actions list",            "List all actions"},
                    {"rule-actions show <ActionId>", "Show a rule action"}
                   ]).

%%-----------------------------------------------------------------------------
%% 'resources' command
%%-----------------------------------------------------------------------------

resources(["list"]) ->
    emqx_cli:print("TODO: list resources...~n");

resources(["show", ResourceId]) ->
    emqx_cli:print("TODO: show resource - ~s~n", [ResourceId]);

resources(_usage) ->
    emqx_cli:usage([{"resources list",             "List all resources"},
                    {"resources show <ResourceId>", "Show a resource"}
                   ]).

