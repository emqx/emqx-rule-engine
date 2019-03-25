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

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

-include("rule_engine.hrl").

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
      [t_inspect_action,
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
      [t_add_get_remove_rule,
       t_add_get_remove_rules,
       t_get_rules_for,
       t_add_get_remove_action,
       t_add_get_remove_actions,
       t_get_actions_for,
       t_remove_actions_of,
       t_get_resources,
       t_add_get_remove_resource,
       t_register_resource_types,
       t_get_resource_type,
       t_get_resource_types,
       t_unregister_resource_types_of]},
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
    ok = ekka_mnesia:start(),
    ok = emqx_rule_registry:mnesia(boot),
    emqx_ct_helpers:start_apps([emqx, emqx_rule_engine],
                               [{plugins_etc_dir, emqx_rule_engine, "test/etc/"},   {acl_file, emqx, "etc/acl.conf"}]),
    Config.

end_per_suite(_Config) ->
    emqx_ct_helpers:stop_apps([emqx, emqx_rule_engine]),
    ok.


%%------------------------------------------------------------------------------
%% Group specific setup/teardown
%%------------------------------------------------------------------------------

group(_Groupname) ->
    [].

init_per_group(registry, Config) ->
    Config;
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
    ok = emqx_rule_engine:register_provider(?APP),
    ?assert(length(emqx_rule_registry:get_actions()) >= 2),
    ok.

t_unregister_provider(_Config) ->
    ok = emqx_rule_engine:unregister_provider(?APP),
    ?assert(length(emqx_rule_registry:get_actions()) == 0),
    ok.

t_create_rule(_Config) ->
    ok = emqx_rule_engine:register_provider(?APP),
    {ok, #rule{id = Id}} = emqx_rule_engine:create_rule(
            #{name => <<"debug-rule">>,
              for => 'message.publish',
              rawsql => <<"select * from \"t/a\"">>,
              actions => [{'default:inspect_action', #{arg1 => 1}}],
              description => <<"debug rule">>}),
    ?assertMatch({ok,#rule{id = Id}}, emqx_rule_registry:get_rule(Id)),
    ok = emqx_rule_engine:unregister_provider(?APP),
    emqx_rule_registry:remove_rule(Id),
    ok.

t_create_resource(_Config) ->
    ok = emqx_rule_engine:register_provider(?APP),
    {ok, #resource{id = ResId}} = emqx_rule_engine:create_resource(
            #{name => <<"debug-resource">>,
              type => default_resource,
              config => #{},
              description => <<"debug resource">>}),
    ?assert(true, is_binary(ResId)),
    ok = emqx_rule_engine:unregister_provider(?APP),
    emqx_rule_registry:remove_resource(ResId),
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule actions
%%------------------------------------------------------------------------------

t_inspect_action(_Config) ->
    ok = emqx_rule_engine:register_provider(?APP),
    {ok, #rule{id = Id}} = emqx_rule_engine:create_rule(
                #{name => <<"inspect_rule">>,
                  for => 'message.publish',
                  rawsql => "select * from t1",
                  actions => [{'default:inspect_action', #{a=>1, b=>2}}],
                  description => <<"Inspect rule">>
                  }),
    {ok, Client} = emqx_client:start_link([{username, <<"emqx">>}]),
    {ok, _} = emqx_client:connect(Client),
    emqx_client:publish(Client, <<"t1">>, <<"{\"id\": 1, \"name\": \"ha\"}">>, 0),
    emqx_client:stop(Client),
    emqx_rule_registry:remove_rule(Id),
    ok.

t_republish_action(_Config) ->
    ok = emqx_rule_engine:register_provider(?APP),
    {ok, #rule{id = Id}} = emqx_rule_engine:create_rule(
                #{name => <<"inspect_rule">>,
                  for => 'message.publish',
                  rawsql => "select topic, payload, qos from t1",
                  actions => [{'default:republish_message',
                              #{from => <<"t1">>, to => <<"t2">>}}],
                  description => <<"Republish rule">>
                  }),
    {ok, Client} = emqx_client:start_link([{username, <<"emqx">>}]),
    {ok, _} = emqx_client:connect(Client),
    {ok, _, _} = emqx_client:subscribe(Client, <<"t2">>, 0),

    emqx_client:publish(Client, <<"t1">>, <<"{\"id\": 1, \"name\": \"ha\"}">>, 0),
    receive Info ->
        ct:pal("OK - received msg on topic t2: ~p~n", [Info])
    after 1000 ->
        ct:fail(wait_for_t2)
    end,
    emqx_client:stop(Client),
    emqx_rule_registry:remove_rule(Id),
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

t_add_get_remove_rule(_Config) ->
    RuleId0 = <<"rule-debug-0">>,
    ok = emqx_rule_registry:add_rule(make_simple_rule(RuleId0)),
    ?assertMatch({ok, #rule{name = RuleId0}}, emqx_rule_registry:get_rule(RuleId0)),
    ok = emqx_rule_registry:remove_rule(RuleId0),
    ?assertEqual(not_found, emqx_rule_registry:get_rule(RuleId0)),

    RuleId1 = <<"rule-debug-1">>,
    Rule1 = make_simple_rule(RuleId1),
    ok = emqx_rule_registry:add_rule(Rule1),
    ?assertMatch({ok, #rule{name = RuleId1}}, emqx_rule_registry:get_rule(RuleId1)),
    ok = emqx_rule_registry:remove_rule(Rule1),
    ?assertEqual(not_found, emqx_rule_registry:get_rule(RuleId1)),
    ok.

t_add_get_remove_rules(_Config) ->
    ok = emqx_rule_registry:add_rules(
            [make_simple_rule(<<"rule-debug-1">>),
             make_simple_rule(<<"rule-debug-2">>)]),
    ?assertEqual(2, length(emqx_rule_registry:get_rules())),
    ok = emqx_rule_registry:remove_rules([<<"rule-debug-1">>, <<"rule-debug-2">>]),
    ?assertEqual([], emqx_rule_registry:get_rules()),

    Rule3 = make_simple_rule(<<"rule-debug-3">>),
    Rule4 = make_simple_rule(<<"rule-debug-4">>),
    ok = emqx_rule_registry:add_rules([Rule3, Rule4]),
    ?assertEqual(2, length(emqx_rule_registry:get_rules())),
    ok = emqx_rule_registry:remove_rules([Rule3, Rule4]),
    ?assertEqual([], emqx_rule_registry:get_rules()),
    ok.

t_get_rules_for(_Config) ->
    ?assertEqual(0, length(emqx_rule_registry:get_rules_for('message.publish'))),
    ok = emqx_rule_registry:add_rules(
            [make_simple_rule(<<"rule-debug-1">>),
             make_simple_rule(<<"rule-debug-2">>)]),
    ?assertEqual(2, length(emqx_rule_registry:get_rules_for('message.publish'))),
    ok = emqx_rule_registry:remove_rules([<<"rule-debug-1">>, <<"rule-debug-2">>]),
    ok.

t_add_get_remove_action(_Config) ->
    ActionName0 = <<"action-debug-0">>,
    Action0 = make_simple_action(ActionName0),
    ok = emqx_rule_registry:add_action(Action0),
    ?assertMatch({ok, #action{name = ActionName0}}, emqx_rule_registry:get_action(ActionName0)),
    ok = emqx_rule_registry:remove_action(ActionName0),
    ?assertMatch(not_found, emqx_rule_registry:get_action(ActionName0)),

    ok = emqx_rule_registry:add_action(Action0),
    ?assertMatch({ok, #action{name = ActionName0}}, emqx_rule_registry:get_action(ActionName0)),
    ok = emqx_rule_registry:remove_action(Action0),
    ?assertMatch(not_found, emqx_rule_registry:get_action(ActionName0)),
    ok.

t_add_get_remove_actions(_Config) ->
    InitActionLen = length(emqx_rule_registry:get_actions()),
    ActionName1 = <<"action-debug-1">>,
    ActionName2 = <<"action-debug-2">>,
    Action1 = make_simple_action(ActionName1),
    Action2 = make_simple_action(ActionName2),
    ok = emqx_rule_registry:add_actions([Action1, Action2]),
    ?assertMatch(2, length(emqx_rule_registry:get_actions()) - InitActionLen),
    ok = emqx_rule_registry:remove_actions([ActionName1, ActionName2]),
    ?assertMatch(InitActionLen, length(emqx_rule_registry:get_actions())),

    ok = emqx_rule_registry:add_actions([Action1, Action2]),
    ?assertMatch(2, length(emqx_rule_registry:get_actions()) - InitActionLen),
    ok = emqx_rule_registry:remove_actions([Action1, Action2]),
    ?assertMatch(InitActionLen, length(emqx_rule_registry:get_actions())),
    ok.

t_get_actions_for(_Config) ->
    InitActionLen = length(emqx_rule_registry:get_actions_for('message.publish')),
    ok = emqx_rule_registry:add_actions([make_simple_action(<<"action-debug-1">>),
                                         make_simple_action(<<"action-debug-2">>)]),
    ?assertMatch(2, length(emqx_rule_registry:get_actions_for('message.publish')) - InitActionLen),
    ok = emqx_rule_registry:remove_actions([<<"action-debug-1">>, <<"action-debug-2">>]),
    ok.

t_remove_actions_of(_Config) ->
    ok = emqx_rule_registry:add_actions([make_simple_action(<<"action-debug-1">>),
                                         make_simple_action(<<"action-debug-2">>)]),
    Len1 = length(emqx_rule_registry:get_actions()),
    ?assert(Len1 >= 2),
    ok = emqx_rule_registry:remove_actions_of(?APP),
    ?assert((Len1 - length(emqx_rule_registry:get_actions())) >= 2),
    ok.

t_add_get_remove_resource(_Config) ->
    ResId = <<"resource-debug">>,
    Res = make_simple_resource(ResId),
    ok = emqx_rule_registry:add_resource(Res),
    ?assertMatch({ok, #resource{id = ResId}}, emqx_rule_registry:get_resource(ResId)),
    ok = emqx_rule_registry:remove_resource(ResId),
    ?assertEqual(not_found, emqx_rule_registry:get_resource(ResId)),

    ok = emqx_rule_registry:add_resource(Res),
    ?assertMatch({ok, #resource{id = ResId}}, emqx_rule_registry:get_resource(ResId)),
    ok = emqx_rule_registry:remove_resource(Res),
    ?assertEqual(not_found, emqx_rule_registry:get_resource(ResId)),
    ok.

t_get_resources(_Config) ->
    Res1 = make_simple_resource(<<"resource-debug-1">>),
    Res2 = make_simple_resource(<<"resource-debug-2">>),
    ok = emqx_rule_registry:add_resource(Res1),
    ok = emqx_rule_registry:add_resource(Res2),
    ?assertEqual(2, length(emqx_rule_registry:get_resources())),
    ok.

t_register_resource_types(_Config) ->
    ResType1 = make_simple_resource_type(<<"resource-type-debug-1">>),
    ResType2 = make_simple_resource_type(<<"resource-type-debug-2">>),
    emqx_rule_registry:register_resource_types([ResType1,ResType2]),
    ok.

t_get_resource_type(_Config) ->
    ?assertMatch({ok, #resource_type{name = <<"resource-type-debug-1">>}}, emqx_rule_registry:get_resource_type(<<"resource-type-debug-1">>)),
    ok.

t_get_resource_types(_Config) ->
    ?assert(length(emqx_rule_registry:get_resource_types()) > 0),
    ok.

t_unregister_resource_types_of(_Config) ->
    ok = emqx_rule_registry:unregister_resource_types_of(?APP),
    ?assertEqual(0, length(emqx_rule_registry:get_resource_types())),
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

%%------------------------------------------------------------------------------
%% Internal helpers
%%------------------------------------------------------------------------------

make_simple_rule(RuleName) when is_binary(RuleName) ->
    #rule{id = RuleName,
          name = RuleName,
          for = 'message.publish',
          rawsql = <<"select * from 'simple/topic'">>,
          topics = [<<"simple/topic">>],
          selects = [<<"*">>],
          conditions = {},
          actions = [{'default:inspect_action', #{}}],
          description = <<"simple rule">>}.

make_simple_action(ActionName) when is_binary(ActionName) ->
    #action{name = ActionName, for = 'message.publish', app = emqx_rule_engine,
            module = ?MODULE, func = fun simple_action_inspect/1, params = #{},
            description = <<"Simple inspect action">>}.

simple_action_inspect(Params) ->
    fun(Data) ->
        io:format("Action InputData: ~p, Action InitParams: ~p~n", [Data, Params])
    end.

make_simple_resource(ResId) ->
    #resource{id = ResId,
              type = simple_resource_type,
              config = #{},
              description = <<"Simple Resource">>}.

make_simple_resource_type(ResTypeName) ->
    #resource_type{name = ResTypeName, provider = ?APP,
                   params = #{},
                   on_create = {?MODULE, on_simple_resource_type_create},
                   description = <<"Simple Resource Type">>}.

on_simple_resource_type_create(#{}) ->
    #{}.