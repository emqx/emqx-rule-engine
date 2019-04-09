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
        , resource_types/1
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
    [rules, {'rule-actions', actions}, resources, {'resource-types', resource_types}].

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
    print_with(fun emqx_rule_registry:get_rule/1, list_to_binary(RuleId));

rules(["create", Name, Hook, SQL, ActionName, ActionParams, Descr]) ->
    case parse_rule_opts(Name, Hook, SQL, ActionName, ActionParams, Descr) of
        {ok, Rule} ->
            case emqx_rule_engine:create_rule(Rule) of
                {ok, #rule{id = RuleId}} ->
                    emqx_cli:print("Rule ~s created~n", [RuleId]);
                {error, Reason} ->
                    emqx_cli:print("~p~n", [Reason])
            end;
        {error, Reason} ->
            emqx_cli:print("Invalid options: ~p~n", [Reason])
    end;

rules(["create" | _Opts]) ->
    emqx_cli:print("Usage:~n~n"
                   "emqx_ctl rules create <Name> <Hook> <SQL> <ActionName> <ActionParams> <Description>~n");

rules(["delete", RuleId]) ->
    ok = emqx_rule_registry:remove_rule(list_to_binary(RuleId)),
    emqx_cli:print("ok~n");

rules(_usage) ->
    emqx_cli:usage([{"rules list",          "List all rules"},
                    {"rules show <RuleId>", "Show a rule"},
                    {"rules create", "Create a rule"},
                    {"rules delete <RuleId>", "Delete a rule"}
                   ]).

%%-----------------------------------------------------------------------------
%% 'rule-actions' command
%%-----------------------------------------------------------------------------

actions(["list"]) ->
    print_all(emqx_rule_registry:get_actions());

actions(["show", ActionId]) ->
    print_with(fun emqx_rule_registry:find_action/1, list_to_existing_atom(ActionId));

actions(_usage) ->
    emqx_cli:usage([{"rule-actions list",            "List all actions"},
                    {"rule-actions show <ActionId>", "Show a rule action"}
                   ]).

%%------------------------------------------------------------------------------
%% 'resources' command
%%------------------------------------------------------------------------------
resources(["create", Name, Type, Config, Descr]) ->
    case parse_resource_opts(Name, Type, Config, Descr) of
        {ok, Res} ->
            case emqx_rule_engine:create_resource(Res) of
                {ok, #resource{id = ResId}} ->
                    emqx_cli:print("Resource ~s created~n", [ResId]);
                {error, Reason} ->
                    emqx_cli:print("~p~n", [Reason])
            end;
        {error, Reason} ->
            emqx_cli:print("Invalid options: ~p~n", [Reason])
    end;

resources(["create" | _Opts]) ->
    emqx_cli:print("Usage:~n~n"
                   "emqx_ctl resources create <Name> <Type> <Config> <Description>~n");

resources(["list"]) ->
    print_all(emqx_rule_registry:get_resources());

resources(["show", ResourceId]) ->
    print_with(fun emqx_rule_registry:find_resource/1, ResourceId);

resources(["delete", ResourceId]) ->
    ok = emqx_rule_registry:remove_resource(list_to_binary(ResourceId)),
    emqx_cli:print("ok~n");

resources(_usage) ->
    emqx_cli:usage([{"resources create", "Create a resource"},
                    {"resources list", "List all resources"},
                    {"resources show <ResourceId>", "Show a resource"},
                    {"resources delete <ResourceId>", "Delete a resource"}
                   ]).

%%------------------------------------------------------------------------------
%% 'resource-types' command
%%------------------------------------------------------------------------------
resource_types(["list"]) ->
    print_all(emqx_rule_registry:get_resource_types());

resource_types(["show", Name]) ->
    print_with(fun emqx_rule_registry:find_resource_type/1, list_to_atom(Name));

resource_types(_usage) ->
    emqx_cli:usage([{"resource-types list", "List all resource-types"},
                    {"resource-types show <Type>", "Show a resource-type"}
                   ]).

%%------------------------------------------------------------------------------
%% Internal functions
%%------------------------------------------------------------------------------

print(Data) ->
    emqx_cli:print(format(Data)).

print_all(DataList) ->
    lists:map(fun(Data) ->
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
             for = Hook,
             rawsql = Sql,
             actions = Actions,
             enabled = Enabled,
             description = Descr}) ->
    lists:flatten(io_lib:format("rule(~s, name=~s, for=~s, rawsql=~s, actions=~p, enabled=~s, description=~s)~n", [Id, Name, Hook, Sql, action_names(Actions), Enabled, Descr]));

format(#action{name = Name,
               app = App,
               params = Params,
               description = Descr}) ->
    lists:flatten(io_lib:format("action(name=~s, app=~s, params=~w, description=~s)~n",
                                [Name, App, Params, Descr]));

format(#resource{id = Id,
                 type = Type,
                 config = Config,
                 attrs = Attrs,
                 description = Descr}) ->
    lists:flatten(io_lib:format("resource(~s, type=~s, config=~w, attrs=~w, description=~s)~n",
                                [Id, Type, Config, Attrs, Descr]));

format(#resource_type{name = Name,
                      provider = Provider,
                      params = Params,
                      on_create = OnCreate,
                      description = Descr}) ->
    lists:flatten(io_lib:format("resource_type(name=~s, provider=~s, params=~w, on_create=~w, description=~s)~n", [Name, Provider, Params, OnCreate, Descr])).

parse_rule_opts(Name, Hook, SQL, ActionName, ActionParams, Descr) ->
    try
        {ok, #{name => Name,
               for => list_to_existing_atom(Hook),
               rawsql => list_to_binary(SQL),
               actions => [{list_to_existing_atom(ActionName),
                           jsx:decode(list_to_binary(ActionParams), [return_maps])}],
               description => Descr}}
    catch
        _Error:Reason ->
            {error, Reason}
    end.

parse_resource_opts(Name, Type, Config, Descr) ->
    try
        {ok, #{name => Name,
               type => list_to_existing_atom(Type),
               config => jsx:decode(list_to_binary(Config)),
               description => Descr}}
    catch
        _Error:Reason ->
            {error, Reason}
    end.

action_names(Actions) when is_list(Actions) ->
    [Name || #{name := Name} <- Actions].