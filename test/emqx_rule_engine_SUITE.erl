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

-module(emqx_rule_engine_SUITE).

-include_lib("proper/include/proper.hrl").
-include_lib("common_test/include/ct.hrl").

%% comman test API
-export([ all/0
        , suite/0
        , groups/0
        , init_per_suite/1
        , end_per_suite/1
        , group/1
        , init_per_group/2
        , end_per_group/2
        , init_per_testcase/2
        , end_per_testcase/2
        ]).

%% test cases for emqx_rule_engine
-export([ t_register_provider/1
        , t_unregister_provider/1
        , t_create_rule/1
        , t_create_resource/1
        ]).

%% test cases for emqx_rule_actions
-export([ t_debug_action/1
        , t_republish_action/1
        ]).

%% test cases for emqx_rule_engine_api
-export([ t_create_rule_api/1
        , t_list_rules_api/1
        , t_show_rule_api/1
        , t_delete_rule_api/1
        , t_list_actions_api/1
        , t_show_action_api/1
        , t_list_resources_api/1
        , t_show_resource_api/1
        , t_list_resource_types_api/1
        , t_show_resource_type_api/1
        ]).

%% test cases for emqx_rule_engine_cli
-export([ t_rules_cli/1
        , t_actions_cli/1
        , t_resources_cli/1
        , t_resource_types_cli/1
        ]).

%% test cases for emqx_rule_funcs
-export([t_topic_func/1]).

%% test cases for emqx_rule_registry
-export([ t_get_rules/1
        , t_get_rules_for/1
        , t_get_rule/1
        , t_add_rule/1
        , t_add_rules/1
        , t_remove_rule/1
        , t_remove_rules/1
        , t_add_action/1
        , t_add_actions/1
        , t_get_actions/1
        , t_get_actions_for/1
        , t_get_action/1
        , t_remove_action/1
        , t_remove_actions/1
        , t_remove_actions_of/1
        , t_get_resources/1
        , t_add_resource/1
        , t_find_resource/1
        , t_remove_resource/1
        , t_get_resource_types/1
        , t_find_resource_type/1
        , t_register_resource_types/1
        , t_unregister_resource_types_of/1
        ]).

%% test cases for emqx_rule_runtime
-export([ t_on_client_connected/1
        , t_on_client_disconnected/1
        , t_on_client_subscribe/1
        , t_on_client_unsubscribe/1
        , t_on_message_publish/1
        , t_on_message_dropped/1
        , t_on_message_deliver/1
        , t_on_message_acked/1
       ]).

%% test cases for emqx_rule_sqlparser
-export([t_sqlparse/1]).

-define(PROPTEST(M,F), true = proper:quickcheck(M:F())).

all() ->
    [ {group, engine}
    , {group, actions}
    , {group, api}
    , {group, cli}
    , {group, funcs}
    , {group, registry}
    , {group, runtime}
    , {group, sqlparse}
    ].

suite() ->
    [{ct_hooks, [cth_surefire]}, {timetrap, {seconds, 30}}].

groups() ->
    [{engine, [sequence],
      [t_register_provider,
       t_unregister_provider,
       t_create_rule,
       t_create_resource
      ]},
     {actions, [],
      [t_debug_action,
       t_republish_action
      ]},
     {api, [],
      [t_create_rule_api,
       t_list_rules_api,
       t_show_rule_api,
       t_delete_rule_api,
       t_list_actions_api,
       t_show_action_api,
       t_list_resources_api,
       t_show_resource_api,
       t_list_resource_types_api,
       t_show_resource_type_api
       ]},
     {cli, [],
      [t_rules_cli,
       t_actions_cli,
       t_resources_cli,
       t_resource_types_cli
      ]},
     {funcs, [],
      [t_topic_func]},
     {registry, [sequence],
      [t_get_rules,
       t_get_rules_for,
       t_get_rule,
       t_add_rule,
       t_add_rules,
       t_remove_rule,
       t_remove_rules,
       t_add_action,
       t_add_actions,
       t_get_actions,
       t_get_actions_for,
       t_get_action,
       t_remove_action,
       t_remove_actions,
       t_remove_actions_of,
       t_get_resources,
       t_add_resource,
       t_find_resource,
       t_remove_resource,
       t_get_resource_types,
       t_find_resource_type,
       t_register_resource_types,
       t_unregister_resource_types_of
      ]},
     {runtime, [sequence],
      [t_on_client_connected,
       t_on_client_disconnected,
       t_on_client_subscribe,
       t_on_client_unsubscribe,
       t_on_message_publish,
       t_on_message_dropped,
       t_on_message_deliver,
       t_on_message_acked
      ]},
     {sqlparse, [],
      [t_sqlparse]}
    ].

%%------------------------------------------------------------------------------
%% Overall setup/teardown
%%------------------------------------------------------------------------------

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.


%%------------------------------------------------------------------------------
%% Group specific setup/teardown
%%------------------------------------------------------------------------------

group(_Groupname) ->
    [].

init_per_group(_Groupname, Config) ->
    Config.

end_per_group(_Groupname, _Config) ->

    ok.

%%------------------------------------------------------------------------------
%% Testcase specific setup/teardown
%%------------------------------------------------------------------------------

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule engine
%%------------------------------------------------------------------------------

t_register_provider(_Config) ->
    %%TODO:
    ok.

t_unregister_provider(_Config) ->
    %%TODO:
    ok.

t_create_rule(_Config) ->
    %%TODO:
    ok.

t_create_resource(_Config) ->
    %%TODO:
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule actions
%%------------------------------------------------------------------------------

t_debug_action(_Config) ->
    %%TODO:
    ok.

t_republish_action(_Config) ->
    %%TODO:
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule engine api
%%------------------------------------------------------------------------------

t_create_rule_api(_Config) ->
    %%TODO:
    ok.

t_list_rules_api(_Config) ->
    %%TODO:
    ok.

t_show_rule_api(_Config) ->
    %%TODO:
    ok.

t_delete_rule_api(_Config) ->
    %%TODO:
    ok.

t_list_actions_api(_Config) ->
    %%TODO:
    ok.

t_show_action_api(_Config) ->
    %%TODO:
    ok.

t_list_resources_api(_Config) ->
    %%TODO:
    ok.

t_show_resource_api(_Config) ->
    %%TODO:
    ok.

t_list_resource_types_api(_Config) ->
    %%TODO:
    ok.

t_show_resource_type_api(_Config) ->
    %%TODO:
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule engine cli
%%------------------------------------------------------------------------------

t_rules_cli(_Config) ->
    %%TODO:
    ok.

t_actions_cli(_Config) ->
    %%TODO:
    ok.

t_resources_cli(_Config) ->
    %%TODO:
    ok.

t_resource_types_cli(_Config) ->
    %%TODO:
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule funcs
%%------------------------------------------------------------------------------

t_topic_func(_Config) ->
    %%TODO:
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule registry
%%------------------------------------------------------------------------------

t_get_rules(_Config) ->
    %%TODO:
    ok.

t_get_rules_for(_Config) ->
    %%TODO:
    ok.

t_get_rule(_Config) ->
    %%TODO:
    ok.

t_add_rule(_Config) ->
    %%TODO:
    ok.

t_add_rules(_Config) ->
    %%TODO:
    ok.

t_remove_rule(_Config) ->
    %%TODO:
    ok.

t_remove_rules(_Config) ->
    %%TODO:
    ok.

t_add_action(_Config) ->
    %%TODO:
    ok.

t_add_actions(_Config) ->
    %%TODO:
    ok.

t_get_actions(_Config) ->
    %%TODO:
    ok.

t_get_actions_for(_Config) ->
    %%TODO:
    ok.

t_get_action(_Config) ->
    %%TODO:
    ok.

t_remove_action(_Config) ->
    %%TODO:
    ok.

t_remove_actions(_Config) ->
    %%TODO:
    ok.

t_remove_actions_of(_Config) ->
    %%TODO:
    ok.

t_get_resources(_Config) ->
    %%TODO:
    ok.

t_add_resource(_Config) ->
    %%TODO:
    ok.

t_find_resource(_Config) ->
    %%TODO:
    ok.

t_remove_resource(_Config) ->
    %%TODO:
    ok.

t_get_resource_types(_Config) ->
    %%TODO:
    ok.

t_find_resource_type(_Config) ->
    %%TODO:
    ok.

t_register_resource_types(_Config) ->
    %%TODO:
    ok.

t_unregister_resource_types_of(_Config) ->
    %%TODO:
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule runtime
%%------------------------------------------------------------------------------


t_on_client_connected(_Config) ->
    %%TODO:
    ok.

t_on_client_disconnected(_Config) ->
    %%TODO:
    ok.

t_on_client_subscribe(_Config) ->
    %%TODO:
    ok.

t_on_client_unsubscribe(_Config) ->
    %%TODO:
    ok.

t_on_message_publish(_Config) ->
    %%TODO:
    ok.

t_on_message_dropped(_Config) ->
    %%TODO:
    ok.

t_on_message_deliver(_Config) ->
    %%TODO:
    ok.

t_on_message_acked(_Config) ->
    %%TODO:
    ok.

%%------------------------------------------------------------------------------
%% Test cases for sqlparser
%%------------------------------------------------------------------------------

t_sqlparse(_Config) ->
    {ok, Select} = emqx_rule_sqlparser:parse_select("select * from topic where x > 10 and y <= 20"),
    [<<"*">>] = emqx_rule_sqlparser:select_fields(Select),
    [<<"topic">>], emqx_rule_sqlparser:select_from(Select),
    {'and',{'>',<<"x">>,<<"10">>},{'<=',<<"y">>,<<"20">>}}
        = emqx_rule_sqlparser:select_where(Select).

