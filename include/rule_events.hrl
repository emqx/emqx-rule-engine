%%--------------------------------------------------------------------
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
%%--------------------------------------------------------------------

-define(EVENT_ALIAS(ALIAS),
        case ALIAS of
           '$message' ->
                [ '$message'
                , '$any'
                , 'message.publish'
                , 'message.delivered'
                , 'message.acked'
                , 'message.dropped'
                ];
           '$client' ->
                [ '$client'
                , '$any'
                , 'client.connected'
                , 'client.disconnected'
                , 'client.subscribe'
                , 'client.unsubscribe'
                ];
           '$session' ->
                [ 'session.subscribed'
                , 'session.unsubscribed'
                ];
           '$any' -> '$any';
           _ -> ['$any', ALIAS]
        end).

-define(COLUMNS(EVENT),
        case EVENT of
        'message.publish' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"id">>
                , <<"payload">>
                , <<"peerhost">>
                , <<"qos">>
                , <<"timestamp">>
                , <<"topic">>
                , <<"node">>
                ];
        'message.delivered' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"mountpoint">>
                , <<"id">>
                , <<"payload">>
                , <<"peerhost">>
                , <<"topic">>
                , <<"qos">>
                , <<"timestamp">>
                , <<"node">>
                ];
        'message.acked' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"id">>
                , <<"payload">>
                , <<"peerhost">>
                , <<"topic">>
                , <<"qos">>
                , <<"timestamp">>
                , <<"node">>
                ];
        'message.dropped' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"id">>
                , <<"payload">>
                , <<"peerhost">>
                , <<"qos">>
                , <<"timestamp">>
                , <<"topic">>
                , <<"node">>
                ];
        'client.connected' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"clean_start">>
                , <<"connack">>
                , <<"connected_at">>
                , <<"is_bridge">>
                , <<"keepalive">>
                , <<"mountpoint">>
                , <<"peerhost">>
                , <<"proto_ver">>
                , <<"timestamp">>
                , <<"node">>
                ];
        'client.disconnected' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"mountpoint">>
                , <<"peerhost">>
                , <<"reason_code">>
                , <<"timestamp">>
                , <<"node">>
                ];
        'client.subscribe' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"mountpoint">>
                , <<"peerhost">>
                , <<"topic_filters">>
                , <<"topic">>
                , <<"qos">>
                , <<"timestamp">>
                , <<"node">>
                ];
        'client.unsubscribe' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"mountpoint">>
                , <<"peerhost">>
                , <<"topic_filters">>
                , <<"topic">>
                , <<"qos">>
                , <<"timestamp">>
                , <<"node">>
                ];
        'session.subscribed' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"topic">>
                , <<"qos">>
                , <<"nl">>
                , <<"rap">>
                , <<"rc">>
                , <<"rh">>
                , <<"timestamp">>
                , <<"node">>
                ];
        'session.unsubscribed' ->
                [ <<"clientid">>
                , <<"username">>
                , <<"event">>
                , <<"topic">>
                , <<"qos">>
                , <<"nl">>
                , <<"rap">>
                , <<"rc">>
                , <<"rh">>
                , <<"timestamp">>
                , <<"node">>
                ];
        RuleType ->
                error({unknown_rule_type, RuleType})
        end).

-define(TEST_COLUMNS_MESSGE,
        [ {<<"clientid">>, <<"c_emqx">>}
        , {<<"username">>, <<"u_emqx">>}
        , {<<"topic">>, <<"t/a">>}
        , {<<"qos">>, 1}
        , {<<"payload">>, <<"{\"msg\": \"hello\"}">>}
        ]).

-define(TEST_COLUMNS(EVENT),
        case EVENT of
        'message.publish' -> ?TEST_COLUMNS_MESSGE;
        'message.delivered' -> ?TEST_COLUMNS_MESSGE;
        'message.acked' -> ?TEST_COLUMNS_MESSGE;
        'message.dropped' -> ?TEST_COLUMNS_MESSGE;
        'client.connected' ->
            [ {<<"clientid">>, <<"c_emqx">>}
            , {<<"username">>, <<"u_emqx">>}
            , {<<"auth_result">>, <<"success">>}
            , {<<"peerhost">>, <<"127.0.0.1">>}
            ];
        'client.disconnected' ->
            [ {<<"clientid">>, <<"c_emqx">>}
            , {<<"username">>, <<"u_emqx">>}
            , {<<"reason_code">>, <<"normal">>}
            ];
        'client.subscribe' ->
            [ {<<"clientid">>, <<"c_emqx">>}
            , {<<"username">>, <<"u_emqx">>}
            , {<<"topic_filters">>,
               [ [{<<"topic">>, <<"t/a">>}, {<<"qos">>, 0}]
               , [{<<"topic">>, <<"t/b">>}, {<<"qos">>, 1}]
               ]}
            ];
        'client.unsubscribe' ->
            [ {<<"clientid">>, <<"c_emqx">>}
            , {<<"username">>, <<"u_emqx">>}
            , {<<"topic_filters">>,
               [ <<"t/a">>
               , <<"t/b">>
               ]}
            ];
        'session.subscribed' ->
            [ {<<"clientid">>, <<"c_emqx">>}
            , {<<"username">>, <<"u_emqx">>}
            , {<<"topic">>, <<"t/a">>}
            , {<<"qos">>, 1}
            ];
        'session.unsubscribed' ->
            [ {<<"clientid">>, <<"c_emqx">>}
            , {<<"username">>, <<"u_emqx">>}
            , {<<"topic">>, <<"t/a">>}
            , {<<"qos">>, 1}
            ];
        RuleType ->
            error({unknown_rule_type, RuleType})
        end).

-define(EVENT_INFO_MESSAGE_PUBLISH,
        #{ event => 'message.publish',
           title => #{en => <<"message publish">>, zh => <<"消息发布"/utf8>>},
           description => #{en => <<"message publish">>, zh => <<"消息发布"/utf8>>},
           test_columns => ?TEST_COLUMNS('message.publish'),
           columns => ?COLUMNS('message.publish'),
           sql_example => <<"SELECT payload.msg as msg FROM \"message.publish\" WHERE topic =~ 't/#' and msg = 'hello'">>
        }).

-define(EVENT_INFO_MESSAGE_DELIVER,
        #{ event => 'message.delivered',
           title => #{en => <<"message delivered">>, zh => <<"消息投递"/utf8>>},
           description => #{en => <<"message delivered">>, zh => <<"消息投递"/utf8>>},
           test_columns => ?TEST_COLUMNS('message.delivered'),
           columns => ?COLUMNS('message.delivered'),
           sql_example => <<"SELECT payload.msg as msg FROM \"message.delivered\" WHERE topic =~ 't/#' and msg = 'hello'">>
        }).

-define(EVENT_INFO_MESSAGE_ACKED,
        #{ event => 'message.acked',
           title => #{en => <<"message acked">>, zh => <<"消息应答"/utf8>>},
           description => #{en => <<"message acked">>, zh => <<"消息应答"/utf8>>},
           test_columns => ?TEST_COLUMNS('message.acked'),
           columns => ?COLUMNS('message.acked'),
           sql_example => <<"SELECT payload.msg as msg FROM \"message.acked\" WHERE topic =~ 't/#' and msg = 'hello'">>
        }).

-define(EVENT_INFO_MESSAGE_DROPPED,
        #{ event => 'message.dropped',
           title => #{en => <<"message dropped">>, zh => <<"消息丢弃"/utf8>>},
           description => #{en => <<"message dropped">>, zh => <<"消息丢弃"/utf8>>},
           test_columns => ?TEST_COLUMNS('message.dropped'),
           columns => ?COLUMNS('message.dropped'),
           sql_example => <<"SELECT payload.msg as msg FROM \"message.dropped\" WHERE topic =~ 't/#' and msg = 'hello'">>
        }).

-define(EVENT_INFO_CLIENT_CONNECTED,
        #{ event => 'client.connected',
           title => #{en => <<"client connected">>, zh => <<"连接建立"/utf8>>},
           description => #{en => <<"client connected">>, zh => <<"连接建立"/utf8>>},
           test_columns => ?TEST_COLUMNS('client.connected'),
           columns => ?COLUMNS('client.connected'),
           sql_example => <<"SELECT * FROM \"client.connected\"">>
        }).

-define(EVENT_INFO_CLIENT_DISCONNECTED,
        #{ event => 'client.disconnected',
           title => #{en => <<"client disconnected">>, zh => <<"连接断开"/utf8>>},
           description => #{en => <<"client disconnected">>, zh => <<"连接断开"/utf8>>},
           test_columns => ?TEST_COLUMNS('client.disconnected'),
           columns => ?COLUMNS('client.disconnected'),
           sql_example => <<"SELECT * FROM \"client.disconnected\"">>
        }).

-define(EVENT_INFO_CLIENT_SUBSCRIBE,
        #{ event => 'client.subscribe',
           title => #{en => <<"client subscribe">>, zh => <<"终端订阅"/utf8>>},
           description => #{en => <<"client subscribe">>, zh => <<"终端订阅"/utf8>>},
           test_columns => ?TEST_COLUMNS('client.subscribe'),
           columns => ?COLUMNS('client.subscribe'),
           sql_example => <<"SELECT * FROM \"client.subscribe\" WHERE topic =~ 't/#'">>
        }).

-define(EVENT_INFO_CLIENT_UNSUBSCRIBE,
        #{ event => 'client.unsubscribe',
           title => #{en => <<"client unsubscribe">>, zh => <<"终端取消订阅"/utf8>>},
           description => #{en => <<"client unsubscribe">>, zh => <<"终端取消订阅"/utf8>>},
           test_columns => ?TEST_COLUMNS('client.unsubscribe'),
           columns => ?COLUMNS('client.unsubscribe'),
           sql_example => <<"SELECT * FROM \"client.unsubscribe\" WHERE topic =~ 't/#'">>
        }).

-define(EVENT_INFO_SESSION_SUBSCRIBED,
        #{ event => 'session.subscribed',
           title => #{en => <<"session subscribed">>, zh => <<"会话订阅完成"/utf8>>},
           description => #{en => <<"session subscribed">>, zh => <<"会话订阅完成"/utf8>>},
           test_columns => ?TEST_COLUMNS('session.subscribed'),
           columns => ?COLUMNS('session.subscribed'),
           sql_example => <<"SELECT * FROM \"session.subscribed\" WHERE topic =~ 't/#'">>
        }).

-define(EVENT_INFO_SESSION_UNSUBSCRIBED,
        #{ event => 'session.unsubscribed',
           title => #{en => <<"session unsubscribed">>, zh => <<"会话取消订阅完成"/utf8>>},
           description => #{en => <<"session unsubscribed">>, zh => <<"会话取消订阅完成"/utf8>>},
           test_columns => ?TEST_COLUMNS('session.unsubscribed'),
           columns => ?COLUMNS('session.unsubscribed'),
           sql_example => <<"SELECT * FROM \"session.unsubscribed\" WHERE topic =~ 't/#'">>
        }).

-define(EVENT_INFO,
        [ ?EVENT_INFO_MESSAGE_PUBLISH
        , ?EVENT_INFO_MESSAGE_DELIVER
        , ?EVENT_INFO_MESSAGE_ACKED
        , ?EVENT_INFO_MESSAGE_DROPPED
        , ?EVENT_INFO_CLIENT_CONNECTED
        , ?EVENT_INFO_CLIENT_DISCONNECTED
        , ?EVENT_INFO_CLIENT_SUBSCRIBE
        , ?EVENT_INFO_CLIENT_UNSUBSCRIBE
        , ?EVENT_INFO_SESSION_SUBSCRIBED
        , ?EVENT_INFO_SESSION_UNSUBSCRIBED
        ]).

-define(EG_ENVS(EVENT),
        case EVENT of
        'message.publish' ->
            #{event => 'message.publish',
              flags => #{dup => false,retain => false},
              from => <<"c_emqx">>,
              headers =>
                  #{allow_publish => true,
                    peerhost => {127,0,0,1},
                    username => <<"u_emqx">>},
              id => <<0,5,137,164,41,233,87,47,180,75,0,0,5,124,0,1>>,
              payload => <<"{\"id\": 1, \"name\": \"ha\"}">>,qos => 1,
              timestamp => emqx_rule_utils:now_ms(),
              node => node(),
              topic => <<"t1">>};
        'message.delivered' ->
            #{anonymous => true,auth_result => success,
              clientid => <<"c_emqx">>,
              event => 'message.delivered',
              flags => #{dup => false,retain => false},
              from => <<"c_emqx">>,
              headers =>
                  #{allow_publish => true,
                    peerhost => {127,0,0,1},
                    username => <<"u_emqx">>},
              id => <<0,5,137,164,41,233,87,47,180,75,0,0,5,124,0,1>>,
              mountpoint => undefined,
              payload => <<"{\"id\": 1, \"name\": \"ha\"}">>,
              peerhost => {127,0,0,1},
              qos => 1,
              node => node(),
              timestamp => emqx_rule_utils:now_ms(),
              topic => <<"t1">>,username => <<"u_emqx">>,
              ws_cookie => undefined,zone => external};
        'message.acked' ->
            #{clientid => <<"c_emqx">>,
              event => 'message.acked',
              flags => #{dup => false,retain => false},
              from => <<"c_emqx">>,
              headers =>
                  #{allow_publish => true,
                    peerhost => {127,0,0,1},
                    username => <<"u_emqx">>},
              id => <<0,5,137,164,41,233,87,47,180,75,0,0,5,124,0,1>>,
              payload => <<"{\"id\": 1, \"name\": \"ha\"}">>,qos => 1,
              timestamp => emqx_rule_utils:now_ms(),
              node => node(),
              topic => <<"t1">>,username => <<"u_emqx">>};
        'message.dropped' ->
            #{event => 'message.dropped',
              flags => #{dup => false,retain => false},
              from => <<"c_emqx">>,
              headers =>
                  #{allow_publish => true,
                    peerhost => {127,0,0,1},
                    username => <<"u_emqx">>},
              id => <<0,5,137,164,41,236,124,3,180,75,0,0,5,124,0,2>>,
              node => node(),
              payload => <<"{\"id\": 1, \"name\": \"ha\"}">>,qos => 1,
              timestamp => emqx_rule_utils:now_ms(),
              topic => <<"t1">>};
        'client.connected' ->
            #{anonymous => true,auth_result => success,
              clientid => <<"c_emqx">>,
              connack => 0,
              conninfo =>
                  #{clean_start => true,
                    clientid => <<"emqtt-EMQ-8246dcc49220e7544aa4">>,
                    conn_mod => emqx_connection,
                    conn_props => undefined,expiry_interval => 0,
                    keepalive => 60,peercert => nossl,
                    peername => {{127,0,0,1},51700},
                    proto_name => <<"MQTT">>,proto_ver => 4,
                    receive_maximum => 32,
                    sockname => {{127,0,0,1},1883},
                    socktype => tcp,username => <<"emqx">>},
              event => 'client.connected',mountpoint => undefined,
              peerhost => {127,0,0,1},
              username => <<"u_emqx">>,ws_cookie => undefined,
              node => node(),
              zone => external};
        'client.disconnected' ->
            #{anonymous => true,auth_result => success,
              clientid => <<"c_emqx">>,
              event => 'client.disconnected',mountpoint => undefined,
              peerhost => {127,0,0,1},
              reason_code => closed,
              username => <<"u_emqx">>,ws_cookie => undefined,
              node => node(),
              timestamp => emqx_rule_utils:now_ms(),
              zone => external};
        'client.subscribe' ->
            #{anonymous => true,auth_result => success,
              clientid => <<"c_emqx">>,
              event => 'client.subscribe',mountpoint => undefined,
              peerhost => {127,0,0,1},
              topic_filters =>
                  [{<<"t1">>,#{nl => 0,qos => 1,rap => 0,rc => 1,rh => 0}}],
              username => <<"u_emqx">>,ws_cookie => undefined,
              node => node(),
              timestamp => emqx_rule_utils:now_ms(),
              zone => external};
        'client.unsubscribe' ->
            #{anonymous => true,auth_result => success,
              clientid => <<"c_emqx">>,
              event => 'client.unsubscribe',mountpoint => undefined,
              peerhost => {127,0,0,1},
              sockname => {127,0,0,1},
              topic_filters => [{<<"t1">>,#{}}],
              username => <<"u_emqx">>,ws_cookie => undefined,
              node => node(),
              timestamp => emqx_rule_utils:now_ms(),
              zone => external};
        'session.subscribed' ->
            #{clientid => <<"c_emqx">>,
              event => 'session.subscribed',
              topic => <<"t1">>,
              sub_opts => #{nl => 0,qos => 1,rap => 0,rc => 1,rh => 0},
              username => <<"u_emqx">>,ws_cookie => undefined,
              node => node(),
              timestamp => emqx_rule_utils:now_ms()};
        'session.unsubscribed' ->
            #{clientid => <<"c_emqx">>,
              event => 'session.unsubscribed',
              topic => <<"t1">>,
              sub_opts => #{nl => 0,qos => 1,rap => 0,rc => 1,rh => 0},
              username => <<"u_emqx">>,ws_cookie => undefined,
              node => node(),
              timestamp => emqx_rule_utils:now_ms()};
        RuleType ->
              error({unknown_event_type, RuleType})
        end).
