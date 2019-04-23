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

-module(emqx_rule_engine).

-include("rule_engine.hrl").

-export([ load_providers/0
        , unload_providers/0
        ]).

-export([ create_rule/1
        , create_resource/1
        ]).

-type(rule() :: #rule{}).
-type(action() :: #action{}).
-type(resource() :: #resource{}).
-type(resource_type() :: #resource_type{}).

-export_type([ rule/0
             , action/0
             , resource/0
             , resource_type/0
             ]).

%%------------------------------------------------------------------------------
%% Load resource/action providers from all available applications
%%------------------------------------------------------------------------------

%% Load all providers .
-spec(load_providers() -> ok).
load_providers() ->
    [load_provider(App) || App <- ignore_lib_apps(application:loaded_applications())],
    ok.

-spec(load_provider(App :: atom()) -> ok).
load_provider(App) when is_atom(App) ->
    ok = load_actions(App),
    ok = load_resource_types(App).

%%------------------------------------------------------------------------------
%% Unload providers
%%------------------------------------------------------------------------------
%% Load all providers .
-spec(unload_providers() -> ok).
unload_providers() ->
    [unload_provider(App) || App <- ignore_lib_apps(application:loaded_applications())],
    ok.

%% @doc Unload a provider.
-spec(unload_provider(App :: atom()) -> ok).
unload_provider(App) ->
    ok = emqx_rule_registry:remove_actions_of(App),
    ok = emqx_rule_registry:unregister_resource_types_of(App).

load_actions(App) ->
    Actions = find_actions(App),
    emqx_rule_registry:add_actions(Actions).

load_resource_types(App) ->
    ResourceTypes = find_resource_types(App),
    emqx_rule_registry:register_resource_types(ResourceTypes).

-spec(find_actions(App :: atom()) -> list(action())).
find_actions(App) ->
    lists:map(fun new_action/1, find_attrs(App, rule_action)).

-spec(find_resource_types(App :: atom()) -> list(resource_type())).
find_resource_types(App) ->
    lists:map(fun new_resource_type/1, find_attrs(App, resource_type)).

new_action({App, Mod, #{name := Name,
                        for := Hook,
                        type := Type,
                        func := Func,
                        params := ParamsSpec} = Params}) ->
    %% Check if the action's function exported
    case erlang:function_exported(Mod, Func, 1) of
        true -> ok;
        false -> error({action_func_not_found, Func})
    end,
    ok = emqx_rule_validator:validate_spec(ParamsSpec),
    #action{name = action_name(Type, Name), for = Hook, app = App, type = Type,
            module = Mod, func = Func, params = ParamsSpec,
            description = iolist_to_binary(maps:get(description, Params, ""))}.

new_resource_type({App, Mod, #{name := Name,
                               params := ParamsSpec,
                               create := Create} = Params}) ->
    ok = emqx_rule_validator:validate_spec(ParamsSpec),
    #resource_type{name = Name, provider = App,
                   params = ParamsSpec,
                   on_create = {Mod, Create},
                   description = iolist_to_binary(maps:get(description, Params, ""))}.

find_attrs(App, Def) ->
    [{App, Mod, Attr} || {ok, Modules} <- [application:get_key(App, modules)],
                         Mod <- Modules,
                         {Name, Attrs} <- module_attributes(Mod), Name =:= Def,
                         Attr <- Attrs].

module_attributes(Module) ->
    try Module:module_info(attributes)
    catch
        error:undef -> [];
        error:Reason -> error(Reason)
    end.

%%------------------------------------------------------------------------------
%% Create a rule or resource
%%------------------------------------------------------------------------------

-spec(create_rule(#{}) -> {ok, rule()} | no_return()).
create_rule(Params = #{name := Name,
                       for := Hook,
                       rawsql := Sql,
                       actions := Actions,
                       description := Descr}) ->
    case emqx_rule_sqlparser:parse_select(Sql) of
        {ok, Select} ->
            Rule = #rule{id = rule_id(Name),
                         name = Name,
                         rawsql = Sql,
                         for = Hook,
                         topics = emqx_rule_sqlparser:select_from(Select),
                         selects = emqx_rule_sqlparser:select_fields(Select),
                         conditions = emqx_rule_sqlparser:select_where(Select),
                         actions = [prepare_action(Action) || Action <- Actions],
                         enabled = maps:get(enabled, Params, true),
                         description = iolist_to_binary(Descr)},
            ok = emqx_rule_registry:add_rule(Rule),
            {ok, Rule};
        Error -> error(Error)
    end.

prepare_action({Name, Args}) ->
    case emqx_rule_registry:find_action(Name) of
        {ok, #action{module = M, func = F, params = ParamSpec}} ->
            ok = emqx_rule_validator:validate_params(Args, ParamSpec),
            NewArgs = with_resource_config(Args),
            #{name => Name, params => NewArgs,
              apply => ?RAISE(M:F(NewArgs), {init_action_failure,{{M,F},_REASON_}})};
        not_found ->
            throw({action_not_found, Name})
    end.

with_resource_config(Args = #{<<"$resource">> := ResId}) ->
    case emqx_rule_registry:find_resource(ResId) of
        {ok, #resource{config = Config}} ->
            maps:merge(Args, Config);
        not_found ->
            throw({resource_not_found, ResId})
    end;

with_resource_config(Args) -> Args.

-spec(create_resource(#{}) -> {ok, resource()} | {error, Reason :: term()}).
create_resource(#{name := Name,
                  type := Type,
                  config := Config,
                  description := Descr}) ->
    case emqx_rule_registry:find_resource_type(Type) of
        {ok, #resource_type{on_create = {M, F}, params = ParamSpec}} ->
            ok = emqx_rule_validator:validate_params(Config, ParamSpec),
            ResId = iolist_to_binary([atom_to_list(Type), ":", Name]),
            Resource = #resource{id = ResId,
                                 name = Name,
                                 type = Type,
                                 config = ?RAISE(M:F(Name, Config), {init_resource_failure,{{M,F},_REASON_}}),
                                 description = iolist_to_binary(Descr)},
            ok = emqx_rule_registry:add_resource(Resource),
            {ok, Resource};
        not_found ->
            {error, {resource_type_not_found, Name}}
    end.

rule_id(Name) ->
    iolist_to_binary([Name, ":", integer_to_list(erlang:system_time())]).

action_name(Type, Name) ->
    list_to_atom(lists:concat([Type, ":", Name])).

ignore_lib_apps(Apps) ->
    LibApps = [kernel, stdlib, sasl, appmon, eldap, erts,
               syntax_tools, ssl, crypto, mnesia, os_mon,
               inets, goldrush, gproc, runtime_tools,
               snmp, otp_mibs, public_key, asn1, ssh, hipe,
               common_test, observer, webtool, xmerl, tools,
               test_server, compiler, debugger, eunit, et,
               wx],
    [AppName || {AppName, _, _} <- Apps, not lists:member(AppName, LibApps)].
