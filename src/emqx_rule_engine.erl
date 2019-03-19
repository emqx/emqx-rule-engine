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

-export([ register_provider/1
        , unregister_provider/1
        ]).

-export([ create_rule/1
        , create_resource/1
        ]).

-export([compile_conditions/1]).

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
%% Register an application as rule-engine's provider
%%------------------------------------------------------------------------------

%% Register an application as rule engine's provider.
-spec(register_provider(App :: atom()) -> ok).
register_provider(App) when is_atom(App) ->
    ok = register_actions(App),
    ok = register_resource_types(App).

register_actions(App) ->
    Actions = find_actions(App),
    emqx_rule_registry:add_actions(Actions).

register_resource_types(App) ->
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
                        func := Func,
                        params := Params,
                        description := Descr}}) ->
    %% Check if the action's function exported
    case erlang:function_exported(Mod, Func, 1) of
        true -> ok;
        false -> error({action_func_not_found, Func})
    end,
    Prefix = case App =:= ?MODULE of
                 true -> default;
                 false -> App
             end,
    Name1 = list_to_atom(lists:concat([Prefix, ":", Name])),
    #action{name = Name1, for = Hook, app = App,
            module = Mod, func = Func, params = Params,
            description = Descr}.

new_resource_type({App, Mod, #{name := Name,
                               schema := Prefix,
                               create := Create,
                               description := Descr}}) ->
    Path = lists:concat([code:priv_dir(App), "/", App, ".schema"]),
    {_, Mappings, _Validators} = cuttlefish_schema:files([Path]),
    Params = find_resource_params(Prefix, Mappings),
    #resource_type{name = Name, provider = App,
                   params = maps:from_list(Params),
                   create = {Mod, Create}, description = Descr}.

find_resource_params(Prefix, Mappings) ->
    lists:foldr(
      fun(M, Acc) ->
              Var = cuttlefish_mapping:variable(M),
              case string:prefix(string:join(Var, "."), Prefix ++ ".") of
                  nomatch -> Acc;
                  Param ->
                      [{list_to_atom(Param), cuttlefish_mapping:datatype(M)}|Acc]
              end
      end, [], Mappings).

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
%% Register a provider
%%------------------------------------------------------------------------------

%% Unregister a provider.
-spec(unregister_provider(App :: atom()) -> ok).
unregister_provider(App) ->
    ok = emqx_rule_registry:remove_actions_of(App),
    ok = emqx_rule_registry:unregister_resource_types_of(App).

%%------------------------------------------------------------------------------
%% Create a rule or resource
%%------------------------------------------------------------------------------

-spec(create_rule(#{}) -> {ok, rule()} | {error, Reason :: term()}).
create_rule(Params = #{name := Name,
                       hook := Hook,
                       conditions := Conditions,
                       actions := Actions,
                       enabled := Enabled,
                       description := Descr}) ->
    case init_actions(Actions, []) of
        {ok, Actions1} ->
            Rule = #rule{id = rule_id(Name),
                         name = Name,
                         hook = Hook,
                         topic = maps:get(topic, Params, undefined),
                         conditions = compile_conditions(Conditions),
                         actions = Actions1,
                         enabled = Enabled,
                         description = Descr},
            ok = emqx_rule_registry:add_rule(Rule),
            {ok, Rule};
        {error, Reason} ->
            {error, Reason}
    end.

rule_id(Name) ->
    iolist_to_binary([Name, ":", integer_to_list(erlang:system_time())]).

init_actions([], Acc) ->
    lists:reverse(Acc);

init_actions([{Name, Args}|Actions], Acc) ->
    case emqx_rule_registry:find_action(Name) of
        {ok, #action{module = M, func = F}} ->
            init_actions(Actions, [#{name => Name, args => Args, apply => M:F(Args)}|Acc]);
        not_found ->
            {error, action_not_found}
    end.

compile_conditions(Conditions) ->
    Conditions.

-spec(create_resource(#{}) -> {ok, resource()} | {error, Reason :: term()}).
create_resource(#{name := Name,
                  type := Type,
                  config := Config,
                  description := Description}) ->
    case emqx_rule_registry:find_resource_type(Type) of
        {ok, #resource_type{create = Create}} ->
            ReqFun = Create(Config),
            ResId = iolist_to_binary([atom_to_list(Type), ":", Name]),
            Resource = #resource{id = ResId,
                                 type = Type,
                                 config = Config,
                                 request = ReqFun,
                                 description = Description},
            ok = emqx_rule_registry:add_resource(Resource),
            {ok, Resource};
        not_found ->
            {error, resource_type_not_found}
    end.

