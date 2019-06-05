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

-include_lib("emqx_rule_engine/include/rule_engine.hrl").
-include_lib("emqx/include/emqx.hrl").

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

-define(HOOK_METRICS_TAB, hook_metrics_tab).

%%-define(PROPTEST(M,F), true = proper:quickcheck(M:F())).

all() ->
    [ {group, engine}
    , {group, actions}
    , {group, api}
    , {group, cli}
    , {group, funcs}
    , {group, registry}
    , {group, runtime}
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
      [t_inspect_action
     %,t_republish_action
      ]},
     {api, [],
      [t_crud_rule_api,
       t_list_actions_api,
       t_show_action_api,
       t_crud_resources_api,
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
       t_remove_actions_of,
       t_get_actions_for,
       t_get_resources,
       t_add_get_remove_resource,
       t_resource_types
      ]},
     {runtime, [],
      [t_events,
       t_sqlselect
      ]}
    ].

%%------------------------------------------------------------------------------
%% Overall setup/teardown
%%------------------------------------------------------------------------------

init_per_suite(Config) ->
    ok = ekka_mnesia:start(),
    ok = emqx_rule_registry:mnesia(boot),
    start_apps(),
    Config.

end_per_suite(_Config) ->
    stop_apps(),
    ok.

on_resource_create(_id, _) -> #{}.
on_resource_destroy(_id, _) -> ok.
on_get_resource_status(_id, _) -> #{}.

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

init_per_testcase(t_events, Config) ->
    ok = emqx_rule_engine:load_providers(),
    init_events_counters([ 'message.publish'
                         , 'message.dropped'
                         , 'message.deliver'
                         , 'message.acked'
                         , 'client.connected'
                         , 'client.disconnected'
                         , 'client.subscribe'
                         , 'client.unsubscribe'
                         ]),
    ok = emqx_rule_registry:add_action(
            #action{name = 'hook-metrics-action', app = ?APP,
                    module = ?MODULE, on_create = hook_metrics_action,
                    types=[], params_spec = #{},
                    title = #{en => <<"Hook metrics action">>},
                    description = #{en => <<"Hook metrics action">>}}),
    SQL = "SELECT * FROM \"message.publish\", "
                        "\"message.dropped\", "
                        "\"message.deliver\", "
                        "\"message.acked\", "
                        "\"client.connected\", "
                        "\"client.disconnected\", "
                        "\"client.subscribe\", "
                        "\"client.unsubscribe\"",
    {ok, Rule} = emqx_rule_engine:create_rule(
                    #{rawsql => SQL,
                      actions => [{'inspect', #{}},
                                  {'hook-metrics-action', #{}}],
                      description => <<"Debug rule">>}),
    [{hook_points_rules, Rule} | Config];
init_per_testcase(_TestCase, Config) ->
    ok = emqx_rule_registry:register_resource_types(
            [#resource_type{
                name = built_in,
                provider = ?APP,
                params_spec = #{},
                on_create = {?MODULE, on_resource_create},
                on_destroy = {?MODULE, on_resource_destroy},
                on_status = {?MODULE, on_get_resource_status},
                title = #{en => <<"Built-In Resource Type (debug)">>},
                description = #{en => <<"The built in resource type for debug purpose">>}}]),
    %ct:pal("============ ~p", [ets:tab2list(emqx_resource_type)]),
    Config.

end_per_testcase(t_events, Config) ->
    ets:delete(?HOOK_METRICS_TAB),
    ok = emqx_rule_registry:remove_rule(?config(hook_points_rules, Config)),
    ok = emqx_rule_registry:remove_action('hook-metrics-action');
end_per_testcase(_TestCase, _Config) ->
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule engine
%%------------------------------------------------------------------------------

t_register_provider(_Config) ->
    ok = emqx_rule_engine:load_providers(),
    ?assert(length(emqx_rule_registry:get_actions()) >= 2),
    ok.

t_unregister_provider(_Config) ->
    ok = emqx_rule_engine:unload_providers(),
    ?assert(length(emqx_rule_registry:get_actions()) == 0),
    ok.

t_create_rule(_Config) ->
    ok = emqx_rule_engine:load_providers(),
    {ok, #rule{id = Id}} = emqx_rule_engine:create_rule(
            #{rawsql => <<"select * from \"message.publish\" where topic = 't/a'">>,
              actions => [{'inspect', #{arg1 => 1}}],
              description => <<"debug rule">>}),
    %ct:pal("======== emqx_rule_registry:get_rules :~p", [emqx_rule_registry:get_rules()]),
    ?assertMatch({ok,#rule{id = Id, for = ['message.publish']}}, emqx_rule_registry:get_rule(Id)),
    ok = emqx_rule_engine:unload_providers(),
    emqx_rule_registry:remove_rule(Id),
    ok.

t_create_resource(_Config) ->
    ok = emqx_rule_engine:load_providers(),
    {ok, #resource{id = ResId}} = emqx_rule_engine:create_resource(
            #{type => built_in,
              config => #{},
              description => <<"debug resource">>}),
    ?assert(true, is_binary(ResId)),
    ok = emqx_rule_engine:unload_providers(),
    emqx_rule_registry:remove_resource(ResId),
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule actions
%%------------------------------------------------------------------------------

t_inspect_action(_Config) ->
    ok = emqx_rule_engine:load_providers(),
    {ok, #resource{id = ResId}} = emqx_rule_engine:create_resource(
            #{type => built_in,
              config => #{},
              description => <<"debug resource">>}),
    {ok, #rule{id = Id}} = emqx_rule_engine:create_rule(
                #{rawsql => "select client_id as c, username as u "
                            "from \"message.publish\" "
                            "where topic='t1'",
                  actions => [{'inspect',
                              #{'$resource' => ResId, a=>1, b=>2}}],
                  type => built_in,
                  description => <<"Inspect rule">>
                  }),
    {ok, Client} = emqx_client:start_link([{username, <<"emqx">>}]),
    {ok, _} = emqx_client:connect(Client),
    emqx_client:publish(Client, <<"t1">>, <<"{\"id\": 1, \"name\": \"ha\"}">>, 0),
    emqx_client:stop(Client),
    emqx_rule_registry:remove_rule(Id),
    emqx_rule_registry:remove_resource(ResId),
    ok.

t_republish_action(_Config) ->
    ok = emqx_rule_engine:load_providers(),
    {ok, #rule{id = Id, for = ['message.publish']}} =
        emqx_rule_engine:create_rule(
                    #{rawsql => <<"select topic, payload, qos from \"message.publish\" where topic=t1">>,
                      actions => [{'republish',
                                  #{<<"target_topic">> => <<"t1">>}}],
                      description => <<"builtin-republish-rule">>}),
    {ok, Client} = emqx_client:start_link([{username, <<"emqx">>}]),
    {ok, _} = emqx_client:connect(Client),
    {ok, _, _} = emqx_client:subscribe(Client, <<"t2">>, 0),

    Msg = <<"{\"id\": 1, \"name\": \"ha\"}">>,
    emqx_client:publish(Client, <<"t1">>, Msg, 0),
    receive {publish, #{topic := <<"t2">>, payload := Payload}} ->
        ?assertEqual(Msg, Payload)
    after 1000 ->
        ct:fail(wait_for_t2)
    end,
    emqx_client:stop(Client),
    emqx_rule_registry:remove_rule(Id),
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule engine api
%%------------------------------------------------------------------------------

t_crud_rule_api(_Config) ->
    {ok, [{code, 0}, {data, Rule = #{id := RuleID}}]} =
        emqx_rule_engine_api:create_rule(#{},
                [{<<"name">>, <<"debug-rule">>},
                 {<<"rawsql">>, <<"select * from \"message.publish\" where topic='t/a'">>},
                 {<<"actions">>, [[{<<"name">>,<<"inspect">>},
                                   {<<"params">>,[{<<"arg1">>,1}]}]]},
                 {<<"description">>, <<"debug rule">>}]),
    %ct:pal("RCreated : ~p", [Rule]),

    {ok, [{code, 0}, {data, Rules}]} = emqx_rule_engine_api:list_rules(#{},[]),
    %ct:pal("RList : ~p", [Rules]),
    ?assert(length(Rules) > 0),

    {ok, [{code, 0}, {data, Rule1}]} = emqx_rule_engine_api:show_rule(#{id => RuleID}, []),
    %ct:pal("RShow : ~p", [Rule1]),
    ?assertEqual(Rule, Rule1),

    ?assertMatch({ok, [{code, 0}]}, emqx_rule_engine_api:delete_rule(#{id => RuleID}, [])),

    NotFound = emqx_rule_engine_api:show_rule(#{id => RuleID}, []),
    %ct:pal("Show After Deleted: ~p", [NotFound]),
    ?assertMatch({ok, [{code, 404}, {message, _}]}, NotFound),
    ok.

t_list_actions_api(_Config) ->
    {ok, [{code, 0}, {data, Actions}]} = emqx_rule_engine_api:list_actions(#{},[]),
    %ct:pal("RList : ~p", [Actions]),
    ?assert(length(Actions) > 0),
    ok.

t_show_action_api(_Config) ->
    ?assertMatch({ok, [{code, 0}, {data, #{name := 'inspect'}}]},
                 emqx_rule_engine_api:show_action(#{name => 'inspect'},[])),
    ok.

t_crud_resources_api(_Config) ->
    {ok, [{code, 0}, {data, #{id := ResId}}]} =
        emqx_rule_engine_api:create_resource(#{},
            [{<<"name">>, <<"Simple Resource">>},
            {<<"type">>, <<"built_in">>},
            {<<"config">>, [{<<"a">>, 1}]},
            {<<"description">>, <<"Simple Resource">>}]),
    {ok, [{code, 0}, {data, Resources}]} = emqx_rule_engine_api:list_resources(#{},[]),
    ?assert(length(Resources) > 0),

    ?assertMatch({ok, [{code, 0}, {data, #{id := ResId}}]},
                 emqx_rule_engine_api:show_resource(#{id => ResId},[])),

    ?assertMatch({ok, [{code, 0}]}, emqx_rule_engine_api:delete_resource(#{id => ResId},#{})),

    ?assertMatch({ok, [{code, 404}, _]},
                 emqx_rule_engine_api:show_resource(#{id => ResId},[])),
    ok.

t_list_resource_types_api(_Config) ->
    {ok, [{code, 0}, {data, ResourceTypes}]} = emqx_rule_engine_api:list_resource_types(#{},[]),
    ?assert(length(ResourceTypes) > 0),
    ok.

t_show_resource_type_api(_Config) ->
    RShow = emqx_rule_engine_api:show_resource_type(#{name => 'built_in'},[]),
    %ct:pal("RShow : ~p", [RShow]),
    ?assertMatch({ok, [{code, 0}, {data, #{name := built_in}}]}, RShow),
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule engine cli
%%------------------------------------------------------------------------------

t_rules_cli(_Config) ->
    RCreate = emqx_rule_engine_cli:rules(["create",
                                          "select * from \"message.publish\" where topic='t1'",
                                          "[{\"name\":\"inspect\", \"params\": {\"arg1\": 1}}]",
                                          "-d", "Debug Rule"]),
    %ct:pal("Result : ~p", [RCreate]),
    ?assertMatch({match, _}, re:run(RCreate, "created")),

    RuleId = re:replace(re:replace(RCreate, "Rule\s", "", [{return, list}]), "\screated\n", "", [{return, list}]),

    RList = emqx_rule_engine_cli:rules(["list"]),
    ?assertMatch({match, _}, re:run(RList, RuleId)),
    %ct:pal("RList : ~p", [RList]),
    %ct:pal("table action params: ~p", [ets:tab2list(emqx_action_instance_params)]),

    RShow = emqx_rule_engine_cli:rules(["show", RuleId]),
    ?assertMatch({match, _}, re:run(RShow, RuleId)),
    %ct:pal("RShow : ~p", [RShow]),

    RDelete = emqx_rule_engine_cli:rules(["delete", RuleId]),
    ?assertEqual("\"ok~n\"", RDelete),
    %ct:pal("RDelete : ~p", [RDelete]),
    %ct:pal("table action params after deleted: ~p", [ets:tab2list(emqx_action_instance_params)]),

    RShow2 = emqx_rule_engine_cli:rules(["show", RuleId]),
    ?assertMatch({match, _}, re:run(RShow2, "Cannot found")),
    %ct:pal("RShow2 : ~p", [RShow2]),
    ok.

t_actions_cli(_Config) ->
    RList = emqx_rule_engine_cli:actions(["list"]),
    ?assertMatch({match, _}, re:run(RList, "inspect")),
    %ct:pal("RList : ~p", [RList]),

    RShow = emqx_rule_engine_cli:actions(["show", "inspect"]),
    ?assertMatch({match, _}, re:run(RShow, "inspect")),
    %ct:pal("RShow : ~p", [RShow]),
    ok.

t_resources_cli(_Config) ->
    RCreate = emqx_rule_engine_cli:resources(["create", "built_in", "{\"a\" : 1}", "-d", "test resource"]),
    ResId = re:replace(re:replace(RCreate, "Resource\s", "", [{return, list}]), "\screated\n", "", [{return, list}]),

    RList = emqx_rule_engine_cli:resources(["list"]),
    ?assertMatch({match, _}, re:run(RList, "test resource")),
    %ct:pal("RList : ~p", [RList]),

    RListT = emqx_rule_engine_cli:resources(["list", "-t", "built_in"]),
    ?assertMatch({match, _}, re:run(RListT, "test resource")),
    %ct:pal("RListT : ~p", [RListT]),

    RShow = emqx_rule_engine_cli:resources(["show", ResId]),
    ?assertMatch({match, _}, re:run(RShow, "test resource")),
    %ct:pal("RShow : ~p", [RShow]),

    RDelete = emqx_rule_engine_cli:resources(["delete", ResId]),
    ?assertEqual("\"ok~n\"", RDelete),

    RShow2 = emqx_rule_engine_cli:resources(["show", ResId]),
    ?assertMatch({match, _}, re:run(RShow2, "Cannot found")),
    %ct:pal("RShow2 : ~p", [RShow2]),
    ok.

t_resource_types_cli(_Config) ->
    RList = emqx_rule_engine_cli:resource_types(["list"]),
    ?assertMatch({match, _}, re:run(RList, "built_in")),
    %ct:pal("RList : ~p", [RList]),

    RShow = emqx_rule_engine_cli:resource_types(["show", "inspect"]),
    ?assertMatch({match, _}, re:run(RShow, "inspect")),
    %ct:pal("RShow : ~p", [RShow]),
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
    ?assertMatch({ok, #rule{id = RuleId0}}, emqx_rule_registry:get_rule(RuleId0)),
    ok = emqx_rule_registry:remove_rule(RuleId0),
    ?assertEqual(not_found, emqx_rule_registry:get_rule(RuleId0)),

    RuleId1 = <<"rule-debug-1">>,
    Rule1 = make_simple_rule(RuleId1),
    ok = emqx_rule_registry:add_rule(Rule1),
    ?assertMatch({ok, #rule{id = RuleId1}}, emqx_rule_registry:get_rule(RuleId1)),
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
    Len0 = length(emqx_rule_registry:get_rules_for('message.publish')),
    ok = emqx_rule_registry:add_rules(
            [make_simple_rule(<<"rule-debug-1">>),
             make_simple_rule(<<"rule-debug-2">>)]),
    ?assertEqual(Len0+2, length(emqx_rule_registry:get_rules_for('message.publish'))),
    ok = emqx_rule_registry:remove_rules([<<"rule-debug-1">>, <<"rule-debug-2">>]),
    ok.

t_add_get_remove_action(_Config) ->
    ActionName0 = 'action-debug-0',
    Action0 = make_simple_action(ActionName0),
    ok = emqx_rule_registry:add_action(Action0),
    ?assertMatch({ok, #action{name = ActionName0}}, emqx_rule_registry:find_action(ActionName0)),
    ok = emqx_rule_registry:remove_action(ActionName0),
    ?assertMatch(not_found, emqx_rule_registry:find_action(ActionName0)),

    ok = emqx_rule_registry:add_action(Action0),
    ?assertMatch({ok, #action{name = ActionName0}}, emqx_rule_registry:find_action(ActionName0)),
    ok = emqx_rule_registry:remove_action(Action0),
    ?assertMatch(not_found, emqx_rule_registry:find_action(ActionName0)),
    ok.

t_add_get_remove_actions(_Config) ->
    InitActionLen = length(emqx_rule_registry:get_actions()),
    ActionName1 = 'action-debug-1',
    ActionName2 = 'action-debug-2',
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

t_remove_actions_of(_Config) ->
    ok = emqx_rule_registry:add_actions([make_simple_action('action-debug-1'),
                                         make_simple_action('action-debug-2')]),
    Len1 = length(emqx_rule_registry:get_actions()),
    ?assert(Len1 >= 2),
    ok = emqx_rule_registry:remove_actions_of(?APP),
    ?assert((Len1 - length(emqx_rule_registry:get_actions())) >= 2),
    ok.

t_get_actions_for(_Config) ->
    Action1 = make_simple_action('action-publish', 'message.publish'),
    Action2 = make_simple_action('action-connected', 'client.connected'),
    Action3 = make_simple_action('action-disconnected', 'client.disconnected'),
    Action4 = make_simple_action('action-subscribe', 'client.subscribe'),
    ok = emqx_rule_registry:add_actions([Action1,Action2,Action3,Action4]),

    MessageActions = emqx_rule_registry:get_actions_for('$message'),
    %ct:pal("MessageActions: ~p", [MessageActions]),
    ?assert(length(MessageActions) >= 1),

    EventActions = emqx_rule_registry:get_actions_for('$client'),
    %ct:pal("EventActions: ~p", [EventActions]),
    ?assert(length(EventActions) >= 3),

    EventDisconn = emqx_rule_registry:get_actions_for('client.disconnected'),
    %ct:pal("EventDisconn: ~p", [EventDisconn]),
    ?assert(length(EventDisconn) >= 1),

    ok = emqx_rule_registry:remove_actions([Action1,Action2,Action3,Action4]).

t_add_get_remove_resource(_Config) ->
    ResId = <<"resource-debug">>,
    Res = make_simple_resource(ResId),
    ok = emqx_rule_registry:add_resource(Res),
    ?assertMatch({ok, #resource{id = ResId}}, emqx_rule_registry:find_resource(ResId)),
    ok = emqx_rule_registry:remove_resource(ResId),
    ?assertEqual(not_found, emqx_rule_registry:find_resource(ResId)),
    ok = emqx_rule_registry:add_resource(Res),
    ?assertMatch({ok, #resource{id = ResId}}, emqx_rule_registry:find_resource(ResId)),
    ok = emqx_rule_registry:remove_resource(Res),
    ?assertEqual(not_found, emqx_rule_registry:find_resource(ResId)),
    ok.
t_get_resources(_Config) ->
    Len0 = length(emqx_rule_registry:get_resources()),
    Res1 = make_simple_resource(<<"resource-debug-1">>),
    Res2 = make_simple_resource(<<"resource-debug-2">>),
    ok = emqx_rule_registry:add_resource(Res1),
    ok = emqx_rule_registry:add_resource(Res2),
    ?assertEqual(Len0+2, length(emqx_rule_registry:get_resources())),
    ok.

t_resource_types(_Config) ->
    register_resource_types(),
    get_resource_type(),
    get_resource_types(),
    unregister_resource_types_of().

register_resource_types() ->
    ResType1 = make_simple_resource_type(<<"resource-type-debug-1">>),
    ResType2 = make_simple_resource_type(<<"resource-type-debug-2">>),
    emqx_rule_registry:register_resource_types([ResType1,ResType2]),
    ok.
get_resource_type() ->
    ?assertMatch({ok, #resource_type{name = <<"resource-type-debug-1">>}}, emqx_rule_registry:find_resource_type(<<"resource-type-debug-1">>)),
    ok.
get_resource_types() ->
    ?assert(length(emqx_rule_registry:get_resource_types()) > 0),
    ok.
unregister_resource_types_of() ->
    ok = emqx_rule_registry:unregister_resource_types_of(?APP),
    ?assertEqual(0, length(emqx_rule_registry:get_resource_types())),
    ok.

%%------------------------------------------------------------------------------
%% Test cases for rule runtime
%%------------------------------------------------------------------------------

t_events(_Config) ->
    {ok, Client} = emqx_client:start_link([{username, <<"emqx">>}]),
    client_connected(Client),
    client_subscribe(Client),
    message_publish(Client),
    message_deliver(Client),
    message_acked(Client),
    client_unsubscribe(Client),
    message_dropped(Client),
    client_disconnected(Client),
    ok.

client_connected(Client) ->
    {ok, _} = emqx_client:connect(Client),
    verify_events_counter('client.connected'),
    ok.
client_subscribe(Client) ->
    {ok, _, _} = emqx_client:subscribe(Client, <<"t1">>, 1),
    verify_events_counter('client.subscribe'),
    ok.
message_publish(Client) ->
    emqx_client:publish(Client, <<"t1">>, <<"{\"id\": 1, \"name\": \"ha\"}">>, 1),
    verify_events_counter('message.publish'),
    ok.
message_deliver(_Client) ->
    verify_events_counter('message.deliver'),
    ok.

message_acked(_Client) ->
    verify_events_counter('message.acked'),
    ok.
client_unsubscribe(Client) ->
    {ok, _, _} = emqx_client:unsubscribe(Client, <<"t1">>),
    verify_events_counter('client.unsubscribe'),
    ok.
message_dropped(Client) ->
    message_publish(Client),
    verify_events_counter('message.dropped'),
    ok.
client_disconnected(Client) ->
    ok = emqx_client:stop(Client),
    verify_events_counter('client.disconnected'),
    ok.

t_sqlselect(_Config) ->
    ok = emqx_rule_engine:load_providers(),
    TopicRule = create_simple_repub_rule(
                    <<"t2">>,
                    "SELECT payload.x as x "
                    "FROM \"message.publish\" "
                    "WHERE (topic =~ 't3/#' or topic = 't1') and x = 1"),
    {ok, Client} = emqx_client:start_link([{username, <<"emqx">>}]),
    {ok, _} = emqx_client:connect(Client),
    {ok, _, _} = emqx_client:subscribe(Client, <<"t2">>, 0),
    emqx_client:publish(Client, <<"t1">>, <<"{\"x\":1}">>, 0),
    ct:sleep(100),
    receive {publish, #{topic := T, payload := Payload}} ->
        ?assertEqual(<<"t2">>, T),
        ?assertEqual(<<"{\"x\":1}">>, Payload)
    after 1000 ->
        ct:fail(wait_for_t2)
    end,

    emqx_client:publish(Client, <<"t1">>, <<"{\"x\":2}">>, 0),
    receive {publish, #{topic := <<"t2">>, payload := _}} ->
        ct:fail(unexpected_t2)
    after 1000 ->
        ok
    end,

    emqx_client:publish(Client, <<"t3/a">>, <<"{\"x\":1}">>, 0),
    receive {publish, #{topic := T3, payload := Payload3}} ->
        ?assertEqual(<<"t2">>, T3),
        ?assertEqual(<<"{\"x\":1}">>, Payload3)
    after 1000 ->
        ct:fail(wait_for_t2)
    end,

    emqx_client:stop(Client),
    emqx_rule_registry:remove_rule(TopicRule).

%%------------------------------------------------------------------------------
%% Internal helpers
%%------------------------------------------------------------------------------

make_simple_rule(RuleId) when is_binary(RuleId) ->
    #rule{id = RuleId,
          rawsql = <<"select * from \"message.publish\" where topic='simple/topic'">>,
          for = ['message.publish'],
          selects = [<<"*">>],
          conditions = {},
          actions = [{'inspect', #{}}],
          description = <<"simple rule">>}.

create_simple_repub_rule(TargetTopic, SQL) ->
    {ok, Rule} = emqx_rule_engine:create_rule(
                    #{rawsql => SQL,
                      actions => [{'republish',
                                  #{<<"target_topic">> => TargetTopic}}],
                      description => <<"simple repub rule">>}),
    Rule.

make_simple_action(ActionName) when is_atom(ActionName) ->
    #action{name = ActionName, app = ?APP,
            module = ?MODULE, on_create = simple_action_inspect, params_spec = #{},
            title = #{en => <<"Simple inspect action">>},
            description = #{en => <<"Simple inspect action">>}}.
make_simple_action(ActionName, Hook) when is_atom(ActionName) ->
    #action{name = ActionName, app = ?APP, for = Hook,
            module = ?MODULE, on_create = simple_action_inspect, params_spec = #{},
            title = #{en => <<"Simple inspect action">>},
            description = #{en => <<"Simple inspect action with hook">>}}.

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
                   params_spec = #{},
                   on_create = {?MODULE, on_simple_resource_type_create},
                   title = #{en => <<"Simple Resource Type">>},
                   description = #{en => <<"Simple Resource Type">>}}.

on_simple_resource_type_create(_Id, #{}) ->
    #{}.

hook_metrics_action(_Params) ->
    fun(_Data = #{event := Hookpoint}, _Events) ->
        ets:update_counter(?HOOK_METRICS_TAB, Hookpoint, 1, {Hookpoint, 1})
    end.

verify_events_counter(Hookpoint) ->
    ct:sleep(50),
    ?assert(ets:lookup_element(?HOOK_METRICS_TAB, Hookpoint, 2) > 0).

init_events_counters(Hookpoints) ->
    ets:new(?HOOK_METRICS_TAB, [named_table, set, public]),
    [ets:insert(?HOOK_METRICS_TAB, {H, 0}) || H <- Hookpoints].

%%------------------------------------------------------------------------------
%% Start Apps
%%------------------------------------------------------------------------------

stop_apps() ->
    [application:stop(App) || App <- [emqx_rule_engine, emqx]].

start_apps() ->
    [start_apps(App, SchemaFile, ConfigFile) ||
        {App, SchemaFile, ConfigFile}
            <- [{emqx, deps_path(emqx, "priv/emqx.schema"),
                       deps_path(emqx, "etc/emqx.conf")},
                {emqx_rule_engine, local_path("priv/emqx_rule_engine.schema"),
                                   local_path("etc/emqx_rule_engine.conf")}]].

start_apps(App, SchemaFile, ConfigFile) ->
    read_schema_configs(App, SchemaFile, ConfigFile),
    set_special_configs(App),
    {ok, _} = application:ensure_all_started(App).

read_schema_configs(App, SchemaFile, ConfigFile) ->
    ct:pal("Read configs - SchemaFile: ~p, ConfigFile: ~p", [SchemaFile, ConfigFile]),
    Schema = cuttlefish_schema:files([SchemaFile]),
    Conf = conf_parse:file(ConfigFile),
    NewConfig = cuttlefish_generator:map(Schema, Conf),
    Vals = proplists:get_value(App, NewConfig, []),
    [application:set_env(App, Par, Value) || {Par, Value} <- Vals].

deps_path(App, RelativePath) ->
    %% Note: not lib_dir because etc dir is not sym-link-ed to _build dir
    %% but priv dir is
    Path0 = code:priv_dir(App),
    Path = case file:read_link(Path0) of
               {ok, Resolved} -> Resolved;
               {error, _} -> Path0
           end,
    filename:join([Path, "..", RelativePath]).

local_path(RelativePath) ->
    deps_path(emqx_rule_engine, RelativePath).

set_special_configs(_App) ->
    ok.
