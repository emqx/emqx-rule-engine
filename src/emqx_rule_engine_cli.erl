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

-include("rule_engine.hrl").

-export([ load/0
        , commands/0
        , unload/0
        ]).

-export([ rules/1
        , actions/1
        , resources/1
        ]).

%%-----------------------------------------------------------------------------
%% Load/Unload Commands
%%-----------------------------------------------------------------------------

-spec(load() -> ok).
load() ->
    lists:foreach(
      fun({Cmd, Func}) ->
              emqx_ctl:register_command(Cmd, {?MODULE, Func}, []);
         (Cmd) ->
              emqx_ctl:register_command(Cmd, {?MODULE, Cmd}, [])
      end, commands()).

-spec(commands() -> list(atom())).
commands() ->
    [rules, {'rule-actions', actions}, resources].

-spec(unload() -> ok).
unload() ->
    lists:foreach(
      fun({Cmd, _Func}) ->
              emqx_ctl:unregister_command(Cmd);
         (Cmd) ->
              emqx_ctl:unregister_command(Cmd)
      end, commands()).

%%-----------------------------------------------------------------------------
%% 'rules' command
%%-----------------------------------------------------------------------------

rules(["list"]) ->
    print_all(emqx_rule_registry:get_rules());

rules(["show", RuleId]) ->
    print_with(fun emqx_rule_registry:get_rule/1, RuleId);

% rules(["create", Opts]) ->
%     case parse_rule_opts(Opts) of
%         {ok, Rule} ->
%             case emqx_rule_engine:create_rule(Rule) of
%                 {ok, _Rule} ->
%                     emqx_cli:print("ok~n");
%                 {error, Reason} ->
%                     emqx_cli:print("~p~n", [Reason])
%             end;
%         {error, Reason} ->
%             emqx_cli:print("Invalid options: ~p~n", [Reason])
%     end;

rules(["delete", RuleId]) ->
    ok = emqx_rule_registry:remove_rule(RuleId),
    emqx_cli:print("ok~n");

rules(["create" | _Opts]) ->
    emqx_cli:usage([{"rules create", "--help to see usage"}]);

rules(_usage) ->
    emqx_cli:usage([{"rules list",          "List all rules"},
                    {"rules show <RuleId>", "Show a rule"},
                    {"rules create", "Create a rule"},
                    {"rules delete <RuleId>", "delete a rule"}
                   ]).

%%-----------------------------------------------------------------------------
%% 'rule-actions' command
%%-----------------------------------------------------------------------------

actions(["list"]) ->
    print_all(emqx_rule_registry:get_actions());

actions(["show", ActionId]) ->
    print_with(fun emqx_rule_registry:get_action/1, ActionId);

actions(_usage) ->
    emqx_cli:usage([{"rule-actions list",            "List all actions"},
                    {"rule-actions show <ActionId>", "Show a rule action"}
                   ]).

%%------------------------------------------------------------------------------
%% 'resources' command
%%------------------------------------------------------------------------------

resources(["list"]) ->
    print_all(emqx_rule_registry:get_resources());

resources(["show", ResourceId]) ->
    print_with(fun emqx_rule_registry:find_resource/1, ResourceId);

resources(_usage) ->
    emqx_cli:usage([{"resources list",             "List all resources"},
                    {"resources show <ResourceId>", "Show a resource"}
                   ]).

%%------------------------------------------------------------------------------
%% Internal functions
%%------------------------------------------------------------------------------

print(Data) ->
    emqx_cli:print(format(Data)).

print_all(DataList) ->
    lists:foreach(fun(Data) ->
            print(Data)
        end, DataList).

print_with(FindFun, Key) ->
    case FindFun(Key) of
        {ok, R} ->
            print(R);
        not_found ->
            emqx_cli:print("Cannot found ~s~n", [Key])
    end.

format(#rule{id = Id,
             name = Name,
             hook = HookPoint,
             topic = Topic,
             conditions = Conditions,
             actions = Actions,
             enabled = Enabled,
             description = Descr}) ->
    io_lib:format("rule(~s, name=~s, hook=~s, topic=~s, conditions=~p,"
                       "actions=~p, enabled=~s, description=~s)~n",
                  [Id, Name, HookPoint, Topic, Conditions, Actions, Enabled, Descr]);

format(#action{name = Name,
               app = App,
               params = Params,
               description = Descr}) ->
    io_lib:format("action(name=~s, app=~s, params=~p, description=~s)~n",
                  [Name, App, Params, Descr]);

format(#resource{id = Id,
                 type = Type,
                 config = Config,
                 attrs = Attrs,
                 description = Descr}) ->
    io_lib:format("resource(~s, type=~s, config=~p, attrs=~p, description=~s)~n",
                  [Id, Type, Config, Attrs, Descr]).