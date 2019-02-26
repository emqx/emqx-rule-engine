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

-include("emqx_rule_engine.hrl").

-export([register/1,
         find_actions/1,
         unregister/1]).

-type(rule() :: #rule{}).
-type(action() :: #action{}).

-export_type([rule/0, action/0]).

%% Register an application which provides actions.
-spec(register(App :: atom()) -> ok).
register(App) when is_atom(App) ->
    Actions = find_actions(App),
    emqx_rule_registry:add_actions(Actions).

-spec(find_actions(App :: atom()) -> list(action())).
find_actions(App) ->
    lists:map(fun new_action/1,
              [{App, Mod, Attr} || {ok, Modules} <- [application:get_key(App, modules)],
                                   Mod <- Modules,
                                   {rule_action, Attrs} <- module_attributes(Mod),
                                   Attr <- Attrs]).

new_action({App, Mod, #{name := Name,
                        hook := Hook,
                        func := Func,
                        descr := Descr}}) ->
    true = erlang:function_exported(Mod, Func, 1),
    Prefix = case App =:= ?MODULE of
                 true -> default;
                 false -> App
             end,
    Id = list_to_atom(lists:concat([Prefix, ".", Name])),
    #action{id = Id, name = Name, hook = Hook, app = App,
            module = Mod, func = Func, descr = Descr}.

module_attributes(Module) ->
    try Module:module_info(attributes)
    catch
        error:undef -> [];
        error:Reason -> exit(Reason)
    end.

%% Unregister an application.
-spec(unregister(App :: atom()) -> ok).
unregister(App) ->
    %% TODO:
    Actions = find_actions(App),
    emqx_rule_registry:remove_actions(Actions).

