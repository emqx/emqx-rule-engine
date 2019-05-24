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
        , re_establish_resources/0
        , rebuild_rules/0
        ]).

-export([ create_rule/1
        , create_resource/1
        , test_resource/1
        , delete_resource/1
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

%%------------------------------------------------------------------------------
%% Re-establish resources
%%------------------------------------------------------------------------------

-spec(re_establish_resources() -> ok).
re_establish_resources() ->
    try
        lists:foreach(
            fun(Res = #resource{id = ResId, config = Config, type = Type}) ->
                {ok, #resource_type{on_create = {M, F}}} = emqx_rule_registry:find_resource_type(Type),
                emqx_rule_registry:add_resource(
                    Res#resource{params = init_resource(M, F, ResId, Config)})
            end, emqx_rule_registry:get_resources())
    catch
        _:Error:StackTrace ->
            logger:critical("Can not re-stablish resource: ~p,"
                            "Fix the issue and establish it manually.\n"
                            "Stacktrace: ~p",
                            [Error, StackTrace])
    end.

-spec(rebuild_rules() -> ok).
rebuild_rules() ->
    try
        lists:foreach(
            fun(Rule = #rule{actions = Actions}) ->
                NewRule = Rule#rule{actions =
                    [begin
                        {ok, #action{module = M, func = F}} = emqx_rule_registry:find_action(ActName),
                        Act#{apply => init_action(M, F, Params)}
                     end ||  Act = #{name := ActName, params := Params} <- Actions]},
                emqx_rule_registry:add_rule(NewRule)
            end, emqx_rule_registry:get_rules())
    catch
        _:Error:StackTrace ->
            logger:critical("Can not re-build rule: ~p,"
                            "Fix the issue and establish it manually.\n"
                            "Stacktrace: ~p",
                            [Error, StackTrace])
    end.

-spec(find_actions(App :: atom()) -> list(action())).
find_actions(App) ->
    lists:map(fun new_action/1, find_attrs(App, rule_action)).

-spec(find_resource_types(App :: atom()) -> list(resource_type())).
find_resource_types(App) ->
    lists:map(fun new_resource_type/1, find_attrs(App, resource_type)).

new_action({App, Mod, #{name := Name,
                        for := Hook,
                        types := Types,
                        func := Func,
                        params := ParamsSpec} = Params}) ->
    %% Check if the action's function exported
    case erlang:function_exported(Mod, Func, 1) of
        true -> ok;
        false -> error({action_func_not_found, Func})
    end,
    ok = emqx_rule_validator:validate_spec(ParamsSpec),
    #action{name = Name, for = Hook, app = App, types = Types,
            module = Mod, func = Func, params = ParamsSpec,
            title = maps:get(title, Params, #{en => <<"">>, zh => <<"">>}),
            description = maps:get(description, Params, "")}.

new_resource_type({App, Mod, #{name := Name,
                               params := ParamsSpec,
                               create := Create,
                               destroy := Destroy} = Params}) ->
    ok = emqx_rule_validator:validate_spec(ParamsSpec),
    #resource_type{name = Name, provider = App,
                   params = ParamsSpec,
                   on_create = {Mod, Create},
                   on_destroy = {Mod, Destroy},
                   title = maps:get(title, Params, #{en => <<"">>, zh => <<"">>}),
                   description = maps:get(description, Params, "")}.

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
create_rule(Params = #{rawsql := Sql, actions := Actions}) ->
    case emqx_rule_sqlparser:parse_select(Sql) of
        {ok, Select} ->
            Rule = #rule{id = rule_id(),
                         rawsql = Sql,
                         for = emqx_rule_sqlparser:select_from(Select),
                         selects = emqx_rule_sqlparser:select_fields(Select),
                         conditions = emqx_rule_sqlparser:select_where(Select),
                         actions = [prepare_action(Action) || Action <- Actions],
                         enabled = maps:get(enabled, Params, true),
                         description = maps:get(description, Params, "")},
            ok = emqx_rule_registry:add_rule(Rule),
            {ok, Rule};
        Error -> error(Error)
    end.

prepare_action({Name, Args}) ->
    case emqx_rule_registry:find_action(Name) of
        {ok, #action{module = M, func = F, params = ParamSpec}} ->
            ok = emqx_rule_validator:validate_params(Args, ParamSpec),
            NewArgs = with_resource_params(Args),
            #{name => Name, params => NewArgs,
              apply => init_action(M, F, NewArgs)};
        not_found ->
            throw({action_not_found, Name})
    end.

with_resource_params(Args = #{<<"$resource">> := ResId}) ->
    case emqx_rule_registry:find_resource(ResId) of
        {ok, #resource{params = Params}} ->
            maps:merge(Args, Params);
        not_found ->
            throw({resource_not_found, ResId})
    end;

with_resource_params(Args) -> Args.

-spec(create_resource(#{}) -> {ok, resource()} | {error, Reason :: term()}).
create_resource(#{type := Type, config := Config} = Params) ->
    case emqx_rule_registry:find_resource_type(Type) of
        {ok, #resource_type{on_create = {M, F}, params = ParamSpec}} ->
            ok = emqx_rule_validator:validate_params(Config, ParamSpec),
            ResId = resource_id(),
            Resource = #resource{id = ResId,
                                 type = Type,
                                 params = init_resource(M, F, ResId, Config),
                                 config = Config,
                                 description = iolist_to_binary(maps:get(description, Params, ""))},
            ok = emqx_rule_registry:add_resource(Resource),
            {ok, Resource};
        not_found ->
            {error, {resource_type_not_found, Type}}
    end.

-spec(test_resource(#{}) -> ok | {error, Reason :: term()}).
test_resource(#{type := Type, config := Config}) ->
    case emqx_rule_registry:find_resource_type(Type) of
        {ok, #resource_type{on_create = {ModC,Create}, on_destroy = {ModD,Destroy}, params = ParamSpec}} ->
            try
                ok = emqx_rule_validator:validate_params(Config, ParamSpec),
                ResId = resource_id(),
                Params = init_resource(ModC, Create, ResId, Config),
                clear_resource(ModD, Destroy, ResId, Params),
                ok
            catch Error:Reason ->
                {error, {Error, Reason}}
            end;
        not_found ->
            {error, {resource_type_not_found, Type}}
    end.

-spec(delete_resource(resource_id()) -> ok | {error, Reason :: term()}).
delete_resource(ResId) ->
    case emqx_rule_registry:find_resource(ResId) of
        {ok, #resource{type = ResType, params = Params}} ->
            try
                {ok, #resource_type{on_destroy = {ModD,Destroy}}}
                    = emqx_rule_registry:find_resource_type(ResType),
                clear_resource(ModD, Destroy, ResId, Params),
                ok = emqx_rule_registry:remove_resource(ResId)
            catch
                Error:Reason ->
                    {error, {Error,Reason}}
            end;
        not_found ->
            {error, {resource_not_found, ResId}}
    end.

%%------------------------------------------------------------------------------
%% Internal Functions
%%------------------------------------------------------------------------------

ignore_lib_apps(Apps) ->
    LibApps = [kernel, stdlib, sasl, appmon, eldap, erts,
               syntax_tools, ssl, crypto, mnesia, os_mon,
               inets, goldrush, gproc, runtime_tools,
               snmp, otp_mibs, public_key, asn1, ssh, hipe,
               common_test, observer, webtool, xmerl, tools,
               test_server, compiler, debugger, eunit, et,
               wx],
    [AppName || {AppName, _, _} <- Apps, not lists:member(AppName, LibApps)].

resource_id() ->
    gen_id("resource:", fun emqx_rule_registry:find_resource/1).

rule_id() ->
    gen_id("rule:", fun emqx_rule_registry:get_rule/1).

gen_id(Prefix, TestFun) ->
    Id = iolist_to_binary([Prefix, emqx_rule_id:gen()]),
    case TestFun(Id) of
        not_found -> Id;
        _Res -> gen_id(Prefix, TestFun)
    end.

init_resource(Module, OnCreate, ResId, Config) ->
    ?RAISE(Module:OnCreate(ResId, Config),
           {init_resource_failure, {{Module, OnCreate}, _REASON_}}).

init_action(Module, OnCreate, Params) ->
    ?RAISE(Module:OnCreate(Params), {init_action_failure,{{Module,OnCreate},_REASON_}}).

clear_resource(Module, Destroy, ResId, Params) ->
    ?RAISE(Module:Destroy(ResId, Params),
           {destroy_resource_failure, {{Module, Destroy}, _REASON_}}).