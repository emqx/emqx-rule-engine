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

-import(proplists, [get_value/2]).

-define(OPTSPEC_RESOURCE_TYPE,
        [{type, $t, "type", {atom, undefined}, "Resource Type"}]).
-define(OPTSPEC_ACTION_TYPE,
        [ {type, $t, "type", {atom, undefined}, "Resource Type"}
        , {hook, $k, "hook", {atom, undefined}, "Hook Type"}
        ]).

-define(OPTSPEC_RESOURCES_CREATE,
        [ {name, undefined, undefined, binary, "Resource Name"}
        , {type, undefined, undefined, atom, "Resource Type"}
        , {config, $c, "config", {binary, <<"{}">>}, "Config"}
        , {descr, $d, "descr", {binary, <<"">>}, "Description"}
        ]).

-define(OPTSPEC_RULES_CREATE,
        [{name, undefined, undefined, binary, "Rule Name"}
        ,{hook, undefined, undefined, atom, "On Which Hook"}
        ,{sql, undefined, undefined, binary, "Filter Condition SQL"}
        ,{actions, undefined, undefined, binary, "Action List To Be Used"}
        ,{descr, $d, "descr", {binary, <<"">>}, "Description"}
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

rules(["create" | Params]) ->
    with_opts(fun({Opts, _}) ->
                try emqx_rule_engine:create_rule(make_rule(Opts)) of
                    {ok, #rule{id = RuleId}} ->
                        emqx_cli:print("Rule ~s created~n", [RuleId]);
                    {error, Reason} ->
                        emqx_cli:print("Invalid options: ~p~n", [Reason])
                catch
                    throw:Error ->
                        emqx_cli:print("Invalid options: ~p~n", [Error])
                end
              end, Params, ?OPTSPEC_RULES_CREATE, {?FUNCTION_NAME, create});

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

actions(["list" | Params]) ->
    with_opts(fun({Opts, _}) ->
            print_all(get_actions(get_value(type, Opts), get_value(hook, Opts)))
        end, Params, ?OPTSPEC_ACTION_TYPE, {'rule-actions', list});

actions(["show", ActionId]) ->
    print_with(fun emqx_rule_registry:find_action/1, list_to_existing_atom(ActionId));

actions(_usage) ->
    emqx_cli:usage([{"rule-actions list",            "List all actions"},
                    {"rule-actions show <ActionId>", "Show a rule action"}
                   ]).

%%------------------------------------------------------------------------------
%% 'resources' command
%%------------------------------------------------------------------------------
resources(["create" | Params]) ->
    with_opts(fun({Opts, _}) ->
                try emqx_rule_engine:create_resource(make_resource(Opts)) of
                    {ok, #resource{id = ResId}} ->
                        emqx_cli:print("Resource ~s created~n", [ResId]);
                    {error, Reason} ->
                        emqx_cli:print("Invalid options: ~p~n", [Reason])
                catch
                    throw:Reason ->
                        emqx_cli:print("Invalid options: ~p~n", [Reason])
                end
              end, Params, ?OPTSPEC_RESOURCES_CREATE, {?FUNCTION_NAME, create});

resources(["list"]) ->
    print_all(emqx_rule_registry:get_resources());

resources(["list" | Params]) ->
    with_opts(fun({Opts, _}) ->
            print_all(emqx_rule_registry:get_resources_by_type(
                get_value(type, Opts)))
        end, Params, ?OPTSPEC_RESOURCE_TYPE, {?FUNCTION_NAME, list});

resources(["show", ResourceId]) ->
    print_with(fun emqx_rule_registry:find_resource/1, list_to_binary(ResourceId));

resources(["delete", ResourceId]) ->
    try
        ok = emqx_rule_registry:remove_resource(list_to_binary(ResourceId)),
        emqx_cli:print("ok~n")
    catch
        _Error:Reason ->
            emqx_cli:print("Cannot delete resource as ~p~n", [Reason])
    end;

resources(_usage) ->
    emqx_cli:usage([{"resources create", "Create a resource"},
                    {"resources list [-t <ResourceType>]", "List all resources"},
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
    lists:flatten(io_lib:format("rule(id='~s', name='~s', for='~s', rawsql='~s', actions=~s, enabled='~s', description='~s')~n", [Id, Name, Hook, Sql, printable_actions(Actions), Enabled, Descr]));

format(#action{name = Name,
               for = Hook,
               app = App,
               type = Type,
               params = Params,
               description = Descr}) ->
    lists:flatten(io_lib:format("action(name='~s', app='~s', for='~s', type='~s', params=~0p, description='~s')~n",
                                [Name, App, Hook, Type, Params, Descr]));

format(#resource{id = Id,
                 name = Name,
                 type = Type,
                 config = Config,
                 attrs = Attrs,
                 description = Descr}) ->
    lists:flatten(io_lib:format("resource(id='~s', name='~s', type='~s', config=~0p, attrs=~0p, description='~s')~n", [Id, Name, Type, Config, Attrs, Descr]));

format(#resource_type{name = Name,
                      provider = Provider,
                      params = Params,
                      on_create = OnCreate,
                      description = Descr}) ->
    lists:flatten(io_lib:format("resource_type(name='~s', provider='~s', params=~0p, on_create=~0p, description='~s')~n", [Name, Provider, Params, OnCreate, Descr])).

make_rule(Opts) ->
    Actions = get_value(actions, Opts),
    #{name => get_value(name, Opts),
      for => get_value(hook, Opts),
      rawsql => get_value(sql, Opts),
      actions => lists:map(fun
                    (#{<<"name">> := ActName, <<"params">> := ActParam}) ->
                        {?RAISE(binary_to_existing_atom(ActName, utf8), {action_not_found, ActName}),
                         ActParam};
                    (#{<<"name">> := ActName}) ->
                         {?RAISE(binary_to_existing_atom(ActName, utf8), {action_not_found, ActName}), #{}}
                    end, jsx:decode(Actions, [return_maps])),
      description => get_value(descr, Opts)}.

make_resource(Opts) ->
    Config = get_value(config, Opts),
    #{name => get_value(name, Opts),
      type => get_value(type, Opts),
      config => ?RAISE(jsx:decode(Config, [return_maps]), {invalid_config, Config}),
      description => get_value(descr, Opts)}.

printable_actions(Actions) when is_list(Actions) ->
    jsx:encode([maps:remove(apply, Act) || Act <- Actions]).

with_opts(Action, RawParams, OptSpecList, {CmdObject, CmdName}) ->
    case getopt:parse_and_check(OptSpecList, RawParams) of
        {ok, Params} ->
            Action(Params);
        {error, Reason} ->
            getopt:usage(OptSpecList,
                io_lib:format("emqx_ctl ~s ~s", [CmdObject, CmdName]), standard_io),
            emqx_cli:print("~p~n", [Reason])
    end.

get_actions(undefined, undefined) ->
    emqx_rule_registry:get_actions();
get_actions(Type, undefined) ->
    emqx_rule_registry:get_actions_by_type(Type);
get_actions(undefined, Hook) ->
    emqx_rule_registry:get_actions_for(Hook);
get_actions(Type, Hook) ->
    ActionsByType = emqx_rule_registry:get_actions_by_type(Type),
    ActionsByHook = emqx_rule_registry:get_actions_for(Hook),
    [ActT || ActT <- ActionsByType,
             ActH <- ActionsByHook, ActT =:= ActH].
