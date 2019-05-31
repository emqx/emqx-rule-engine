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

-module(emqx_rule_registry).

-behaviour(gen_server).

-include("rule_engine.hrl").
-include("rule_events.hrl").
-include_lib("emqx/include/logger.hrl").

-export([start_link/0]).

%% Rule Management
-export([ get_rules/0
        , get_rules_for/1
        , get_rule/1
        , add_rule/1
        , add_rules/1
        , remove_rule/1
        , remove_rules/1
        ]).

%% Action Management
-export([ add_action/1
        , add_actions/1
        , get_actions/0
        , get_actions_for/1
        , find_action/1
        , remove_action/1
        , remove_actions/1
        , remove_actions_of/1
        , add_action_instance_params/1
        , get_action_instance_params/1
        , remove_action_instance_params/1
        ]).

%% Resource Management
-export([ get_resources/0
        , add_resource/1
        , add_resource_params/1
        , find_resource/1
        , find_resource_params/1
        , get_resources_by_type/1
        , remove_resource/1
        , remove_resource_params/1
        ]).

%% Resource Types
-export([ get_resource_types/0
        , find_resource_type/1
        , register_resource_types/1
        , unregister_resource_types_of/1
        ]).

%% gen_server Callbacks
-export([ init/1
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , terminate/2
        , code_change/3
        ]).

%% Mnesia bootstrap
-export([mnesia/1]).

-boot_mnesia({mnesia, [boot]}).
-copy_mnesia({mnesia, [copy]}).

-define(REGISTRY, ?MODULE).

%% Tables
-define(RULE_TAB, emqx_rule).
-define(ACTION_TAB, emqx_rule_action).
-define(ACTION_INST_PARAMS_TAB, emqx_action_instance_params).
-define(RES_TAB, emqx_resource).
-define(RES_PARAMS_TAB, emqx_resource_params).
-define(RULE_HOOKS, emqx_rule_hooks).
-define(RES_TYPE_TAB, emqx_resource_type).

%% Statistics
-define(STATS,
        [ {?RULE_TAB, 'rules/count', 'rules/max'}
        , {?ACTION_TAB, 'actions/count', 'actions/max'}
        , {?RES_TAB, 'resources/count', 'resources/max'}
        ]).

%%------------------------------------------------------------------------------
%% Mnesia bootstrap
%%------------------------------------------------------------------------------

%% @doc Create or replicate tables.
-spec(mnesia(boot | copy) -> ok).
mnesia(boot) ->
    %% Optimize storage
    StoreProps = [{ets, [{read_concurrency, true}]}],
    %% Rule table
    ok = ekka_mnesia:create_table(?RULE_TAB, [
                {disc_copies, [node()]},
                {record_name, rule},
                {index, [#rule.for]},
                {attributes, record_info(fields, rule)},
                {storage_properties, StoreProps}]),
    %% Rule action table
    ok = ekka_mnesia:create_table(?ACTION_TAB, [
                {ram_copies, [node()]},
                {record_name, action},
                {index, [#action.for, #action.app]},
                {attributes, record_info(fields, action)},
                {storage_properties, StoreProps}]),
    %% Resource table
    ok = ekka_mnesia:create_table(?RES_TAB, [
                {disc_copies, [node()]},
                {record_name, resource},
                {index, [#resource.type]},
                {attributes, record_info(fields, resource)},
                {storage_properties, StoreProps}]),
    %% Resource type table
    ok = ekka_mnesia:create_table(?RES_TYPE_TAB, [
                {ram_copies, [node()]},
                {record_name, resource_type},
                {index, [#resource_type.provider]},
                {attributes, record_info(fields, resource_type)},
                {storage_properties, StoreProps}]),
    %% Mapping from hook to rule_id
    ok = ekka_mnesia:create_table(?RULE_HOOKS, [
                {type, bag},
                {disc_copies, [node()]},
                {record_name, rule_hooks},
                {attributes, record_info(fields, rule_hooks)},
                {storage_properties, StoreProps}]);

mnesia(copy) ->
    %% Copy rule table
    ok = ekka_mnesia:copy_table(?RULE_TAB),
    %% Copy rule action table
    ok = ekka_mnesia:copy_table(?ACTION_TAB),
    %% Copy resource table
    ok = ekka_mnesia:copy_table(?RES_TAB),
    %% Copy resource type table
    ok = ekka_mnesia:copy_table(?RES_TYPE_TAB),
    %% Copy hook_name -> rule_id table
    ok = ekka_mnesia:copy_table(?RULE_HOOKS).

%%------------------------------------------------------------------------------
%% Start the registry
%%------------------------------------------------------------------------------

-spec(start_link() -> {ok, pid()} | ignore | {error, Reason :: term()}).
start_link() ->
    gen_server:start_link({local, ?REGISTRY}, ?MODULE, [], []).

%%------------------------------------------------------------------------------
%% Rule Management
%%------------------------------------------------------------------------------

-spec(get_rules() -> list(emqx_rule_engine:rule())).
get_rules() ->
    get_all_records(?RULE_TAB).

-spec(get_rules_for(Hook :: hook()) -> list(emqx_rule_engine:rule())).
get_rules_for(Hook) ->
    lists:flatten([mnesia:dirty_read(?RULE_TAB, Id)
                   || #rule_hooks{rule_id = Id} <- mnesia:dirty_read(?RULE_HOOKS, Hook)]).

-spec(get_rule(Id :: rule_id()) -> {ok, emqx_rule_engine:rule()} | not_found).
get_rule(Id) ->
    case mnesia:dirty_read(?RULE_TAB, Id) of
        [Rule] -> {ok, Rule};
        [] -> not_found
    end.

-spec(add_rule(emqx_rule_engine:rule()) -> ok).
add_rule(Rule) when is_record(Rule, rule) ->
    trans(fun insert_rule/1, [Rule]).

-spec(add_rules(list(emqx_rule_engine:rule())) -> ok).
add_rules(Rules) ->
    trans(fun lists:foreach/2, [fun insert_rule/1, Rules]).

-spec(remove_rule(emqx_rule_engine:rule() | rule_id()) -> ok).
remove_rule(RuleOrId) ->
    trans(fun delete_rule/1, [RuleOrId]).

-spec(remove_rules(list(emqx_rule_engine:rule()) | list(rule_id())) -> ok).
remove_rules(Rules) ->
    trans(fun lists:foreach/2, [fun delete_rule/1, Rules]).

%% @private
insert_rule(Rule = #rule{id = Id, for = Hooks}) ->
    [mnesia:write(?RULE_HOOKS, #rule_hooks{hook = H, rule_id = Id}, write) || H <- Hooks],
    mnesia:write(?RULE_TAB, Rule, write).

%% @private
delete_rule(RuleId) when is_binary(RuleId) ->
    case get_rule(RuleId) of
        {ok, Rule} -> delete_rule(Rule);
        not_found -> ok
    end;
delete_rule(Rule = #rule{id = Id, for = Hooks}) when is_record(Rule, rule) ->
    [mnesia:delete_object(?RULE_HOOKS, #rule_hooks{hook = H, rule_id = Id}, write) || H <- Hooks],
    mnesia:delete_object(?RULE_TAB, Rule, write).

%%------------------------------------------------------------------------------
%% Action Management
%%------------------------------------------------------------------------------

%% @doc Get all actions.
-spec(get_actions() -> list(emqx_rule_engine:action())).
get_actions() ->
    get_all_records(?ACTION_TAB).

%% @doc Get actions for a hook or hook alias.
-spec(get_actions_for(Hook :: hook() | list(hook()))
        -> list(emqx_rule_engine:action())).
get_actions_for(HookAlias) ->
    do_get_actions_for(?EVENT_ALIAS(HookAlias)).

-spec(do_get_actions_for(Hook :: hook() | list(hook()))
        -> list(emqx_rule_engine:action())).
do_get_actions_for([]) -> [];
do_get_actions_for([H | T] = Hooks) when is_list(Hooks) ->
    do_get_actions_for(H) ++ do_get_actions_for(T);
do_get_actions_for(Hook) when not is_list(Hook) ->
    mnesia:dirty_index_read(?ACTION_TAB, Hook, #action.for).

%% @doc Find an action by name.
-spec(find_action(Name :: action_name()) -> {ok, emqx_rule_engine:action()} | not_found).
find_action(Name) ->
    case mnesia:dirty_read(?ACTION_TAB, Name) of
        [Action] -> {ok, Action};
        [] -> not_found
    end.

%% @doc Add an action.
-spec(add_action(emqx_rule_engine:action()) -> ok).
add_action(Action) when is_record(Action, action) ->
    trans(fun insert_action/1, [Action]).

%% @doc Add actions.
-spec(add_actions(list(emqx_rule_engine:action())) -> ok).
add_actions(Actions) when is_list(Actions) ->
    trans(fun lists:foreach/2, [fun insert_action/1, Actions]).

%% @doc Remove an action.
-spec(remove_action(emqx_rule_engine:action() | atom()) -> ok).
remove_action(Action) when is_record(Action, action) ->
    trans(fun delete_action/1, [Action]);

remove_action(Name) ->
    trans(fun mnesia:delete/1, [{?ACTION_TAB, Name}]).

%% @doc Remove actions.
-spec(remove_actions(list(emqx_rule_engine:action())) -> ok).
remove_actions(Actions) ->
    trans(fun lists:foreach/2, [fun delete_action/1, Actions]).

%% @doc Remove actions of the App.
-spec(remove_actions_of(App :: atom()) -> ok).
remove_actions_of(App) ->
    trans(fun() ->
            lists:foreach(fun delete_action/1, mnesia:index_read(?ACTION_TAB, App, #action.app))
          end).

%% @private
insert_action(Action) ->
    mnesia:write(?ACTION_TAB, Action, write).

%% @private
delete_action(Action) when is_record(Action, action) ->
    mnesia:delete_object(?ACTION_TAB, Action, write);
delete_action(Name) when is_atom(Name) ->
    mnesia:delete(?ACTION_TAB, Name, write).

%% @doc Add an action instance params.
-spec(add_action_instance_params(emqx_rule_engine:action_instance_params()) -> ok).
add_action_instance_params(ActionInstParams) when is_record(ActionInstParams, action_instance_params) ->
    ets:insert(?ACTION_INST_PARAMS_TAB, ActionInstParams),
    ok.

-spec(get_action_instance_params(action_instance_id()) -> {ok, emqx_rule_engine:action_instance_params()} | not_found).
get_action_instance_params(ActionInstId) ->
    case ets:lookup(?ACTION_INST_PARAMS_TAB, ActionInstId) of
        [ActionInstParams] -> {ok, ActionInstParams};
        [] -> not_found
    end.

%% @doc Delete an action instance params.
-spec(remove_action_instance_params(action_instance_id()) -> ok).
remove_action_instance_params(ActionInstId) ->
    ets:delete(?ACTION_INST_PARAMS_TAB, ActionInstId),
    ok.

%%------------------------------------------------------------------------------
%% Resource Management
%%------------------------------------------------------------------------------

-spec(get_resources() -> list(emqx_rule_engine:resource())).
get_resources() ->
    get_all_records(?RES_TAB).

-spec(add_resource(emqx_rule_engine:resource()) -> ok).
add_resource(Resource) when is_record(Resource, resource) ->
    trans(fun insert_resource/1, [Resource]).

-spec(add_resource_params(emqx_rule_engine:resource_params()) -> ok).
add_resource_params(ResParams) when is_record(ResParams, resource_params) ->
    ets:insert(?RES_PARAMS_TAB, ResParams),
    ok.

-spec(find_resource(Id :: resource_id()) -> {ok, emqx_rule_engine:resource()} | not_found).
find_resource(Id) ->
    case mnesia:dirty_read(?RES_TAB, Id) of
        [Res] -> {ok, Res};
        [] -> not_found
    end.

-spec(find_resource_params(Id :: resource_id())
        -> {ok, emqx_rule_engine:resource_params()} | not_found).
find_resource_params(Id) ->
    case ets:lookup(?RES_PARAMS_TAB, Id) of
        [ResParams] -> {ok, ResParams};
        [] -> not_found
    end.

-spec(remove_resource(emqx_rule_engine:resource() | emqx_rule_engine:resource_id()) -> ok).
remove_resource(Resource) when is_record(Resource, resource) ->
    trans(fun delete_resource/1, [Resource#resource.id]);

remove_resource(ResId) when is_binary(ResId) ->
    trans(fun delete_resource/1, [ResId]).

-spec(remove_resource_params(emqx_rule_engine:resource_id()) -> ok).
remove_resource_params(ResId) ->
    ets:delete(?RES_PARAMS_TAB, ResId),
    ok.

%% @private
delete_resource(ResId) ->
    [[ResId =:= ResId1 andalso throw({dependency_exists, {rule, Id}})
        || #{params := #{<<"$resource">> := ResId1}} <- Actions]
            || #rule{id = Id, actions = Actions} <- get_rules()],
    mnesia:delete(?RES_TAB, ResId, write).

%% @private
insert_resource(Resource) ->
    mnesia:write(?RES_TAB, Resource, write).

%%------------------------------------------------------------------------------
%% Resource Type Management
%%------------------------------------------------------------------------------

-spec(get_resource_types() -> list(emqx_rule_engine:resource_type())).
get_resource_types() ->
    get_all_records(?RES_TYPE_TAB).

-spec(find_resource_type(Name :: resource_type_name()) -> {ok, emqx_rule_engine:resource_type()} | not_found).
find_resource_type(Name) ->
    case mnesia:dirty_read(?RES_TYPE_TAB, Name) of
        [ResType] -> {ok, ResType};
        [] -> not_found
    end.

-spec(get_resources_by_type(Type :: resource_type_name()) -> list(emqx_rule_engine:resource())).
get_resources_by_type(Type) ->
    mnesia:dirty_index_read(?RES_TAB, Type, #resource.type).

-spec(register_resource_types(list(emqx_rule_engine:resource_type())) -> ok).
register_resource_types(Types) ->
    trans(fun lists:foreach/2, [fun insert_resource_type/1, Types]).

%% @doc Unregister resource types of the App.
-spec(unregister_resource_types_of(App :: atom()) -> ok).
unregister_resource_types_of(App) ->
    trans(fun() ->
            lists:foreach(fun delete_resource_type/1, mnesia:index_read(?RES_TYPE_TAB, App, #resource_type.provider))
          end).

%% @private
insert_resource_type(Type) ->
    mnesia:write(?RES_TYPE_TAB, Type, write).

%% @private
delete_resource_type(Type) ->
    mnesia:delete_object(?RES_TYPE_TAB, Type, write).

%%------------------------------------------------------------------------------
%% gen_server callbacks
%%------------------------------------------------------------------------------

init([]) ->
    Opts = [public, named_table, set, {read_concurrency, true}],
    ets:new(?ACTION_INST_PARAMS_TAB, [{keypos, #action_instance_params.id}|Opts]),
    ets:new(?RES_PARAMS_TAB, [{keypos, #resource_params.id}|Opts]),
    %% Enable stats timer
    ok = emqx_stats:update_interval(rule_registery_stats, fun update_stats/0),
    {ok, #{}}.

handle_call(Req, _From, State) ->
    ?LOG(error, "[RuleRegistry]: unexpected call - ~p", [Req]),
    {reply, ignored, State}.

handle_cast(Msg, State) ->
    ?LOG(error, "[RuleRegistry]: unexpected cast ~p", [Msg]),
    {noreply, State}.

handle_info(Info, State) ->
    ?LOG(error, "[RuleRegistry]: unexpected info ~p", [Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    emqx_stats:cancel_update(rule_registery_stats).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%------------------------------------------------------------------------------
%% Private functions
%%------------------------------------------------------------------------------

update_stats() ->
    lists:foreach(
      fun({Tab, Stat, MaxStat}) ->
              Size = mnesia:table_info(Tab, size),
              emqx_stats:setstat(Stat, MaxStat, Size)
      end, ?STATS).

get_all_records(Tab) ->
    mnesia:dirty_match_object(Tab, mnesia:table_info(Tab, wild_pattern)).

trans(Fun) -> trans(Fun, []).
trans(Fun, Args) ->
    case mnesia:transaction(Fun, Args) of
        {atomic, ok} -> ok;
        {aborted, Reason} -> error(Reason)
    end.
