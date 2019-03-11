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

-include("rule_engine.hrl").

%% Mnesia bootstrap
-export([mnesia/1]).

-boot_mnesia({mnesia, [boot]}).
-copy_mnesia({mnesia, [copy]}).

%% Rule Management
-export([get_rules/0,
         get_rules_for/1,
         get_rule/1,
         add_rule/1,
         add_rules/1,
         remove_rule/1,
         remove_rules/1
        ]).

%% Action Management
-export([get_actions/0,
         get_actions_for/1,
         get_action/1,
         add_action/1,
         add_actions/1,
         remove_action/1,
         remove_actions/1
        ]).

%% Tables
-define(RULE_TAB, emqx_rule).
-define(ACTION_TAB, emqx_rule_action).

-type(rule() :: emqx_rule_engine:rule()).
-type(action() :: emqx_rule_engine:action()).

%%------------------------------------------------------------------------------
%% Mnesia bootstrap
%%------------------------------------------------------------------------------

%% @doc Create or replicate trie tables.
-spec(mnesia(boot | copy) -> ok).
mnesia(boot) ->
    %% Optimize storage
    StoreProps = [{ets, [{read_concurrency, true}]}],
    %% Rule table
    ok = ekka_mnesia:create_table(?RULE_TAB, [
                {disc_copies, [node()]},
                {record_name, rule},
                {index, [#rule.hook]},
                {attributes, record_info(fields, rule)},
                {storage_properties, StoreProps}]),
    %% Rule action table
    ok = ekka_mnesia:create_table(?ACTION_TAB, [
                {ram_copies, [node()]},
                {record_name, action},
                {index, [#action.hook]},
                {attributes, record_info(fields, action)},
                {storage_properties, StoreProps}]);

mnesia(copy) ->
    %% Copy rule table
    ok = ekka_mnesia:copy_table(?RULE_TAB),
    %% Copy rule action table
    ok = ekka_mnesia:copy_table(?ACTION_TAB).

%%------------------------------------------------------------------------------
%% Rule Management
%%------------------------------------------------------------------------------

-spec(get_rules() -> list(rule())).
get_rules() ->
    ets:tab2list(?RULE_TAB).

-spec(get_rules_for(Hook :: atom()) -> list(rule())).
get_rules_for(Hook) ->
    mnesia:dirty_index_read(?RULE_TAB, Hook, #rule.hook).

-spec(get_rule(Id :: binary()) -> {ok, rule()} | {error, not_found}).
get_rule(Id) when is_binary(Id) ->
    case mnesia:dirty_read(?RULE_TAB, Id) of
        [Rule] -> {ok, Rule};
        [] -> {error, not_found}
    end.

-spec(add_rule(rule()) -> ok).
add_rule(Rule) ->
    mnesia_trans(fun write_rule/1, [Rule]).

-spec(add_rules(list(rule())) -> ok).
add_rules(Rules) ->
    mnesia_trans(fun lists:foreach/2, [fun write_rule/1, Rules]).

-spec(remove_rule(rule()) -> ok).
remove_rule(Rule) ->
    mnesia_trans(fun delete_rule/1, [Rule]).

-spec(remove_rules(list(rule())) -> ok).
remove_rules(Rules) ->
    mnesia_trans(fun lists:foreach/2, [fun delete_rule/1, Rules]).

%% @private
write_rule(Rule) ->
    mnesia:write(?RULE_TAB, Rule, write).

%% @private
delete_rule(Rule) ->
    mnesia:delete_object(?RULE_TAB, Rule, write).

%%------------------------------------------------------------------------------
%% Action Management
%%------------------------------------------------------------------------------

-spec(get_actions() -> list(action())).
get_actions() ->
    ets:tab2list(?ACTION_TAB).

-spec(get_actions_for(Hook :: atom()) -> list(action())).
get_actions_for(Hook) when is_atom(Hook) ->
    mnesia:dirty_index_read(?ACTION_TAB, Hook, #action.hook).

-spec(get_action(Id :: atom()) -> {ok, action()} | {error, not_found}).
get_action(Id) when is_atom(Id) ->
    case mnesia:dirty_read(?ACTION_TAB, Id) of
        [Action] -> {ok, Action};
        [] -> {error, not_found}
    end.

-spec(add_action(action()) -> ok).
add_action(Action) when is_record(Action, action) ->
    mnesia_trans(fun write_action/1, [Action]).

-spec(add_actions(list(action())) -> ok).
add_actions(Actions) when is_list(Actions) ->
    mnesia_trans(fun lists:foreach/2, [fun write_action/1, Actions]).

-spec(remove_action(action()) -> ok).
remove_action(Action) ->
    %%TODO: How to handle the rules which depend on the action???
    mnesia_trans(fun delete_action/1, [Action]).

-spec(remove_actions(list(action())) -> ok).
remove_actions(Actions) ->
    %%TODO: How to handle the rules which depend on the actions???
    mnesia_trans(fun lists:foreach/2, [fun delete_action/1, Actions]).

%% @private
write_action(Action) ->
    mnesia:write(?ACTION_TAB, Action, write).

%% @private
delete_action(Action) ->
    mnesia:delete_object(?ACTION_TAB, Action, write).

%%------------------------------------------------------------------------------
%% Private Functions
%%------------------------------------------------------------------------------

mnesia_trans(Fun, Args) ->
    case mnesia:transaction(Fun, Args) of
        {atomic, ok} -> ok;
        {aborted, Reason} -> error(Reason)
    end.


