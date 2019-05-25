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

-define(EVENT_ALIAS(ALIAS),
        case ALIAS of
           '$message' ->
                [ '$message'
                , '$any'
                , 'message.publish'
                , 'message.deliver'
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
           _ -> ['$any', ALIAS]
        end).

-define(COLUMNS(EVENT),
        case EVENT of
        'message.publish' ->
                [ <<"client_id">>
                , <<"username">>
                , <<"event">>
                , <<"flags">>
                , <<"id">>
                , <<"payload">>
                , <<"peername">>
                , <<"qos">>
                , <<"timestamp">>
                , <<"topic">>
                ];
        'message.deliver' ->
                [ <<"client_id">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"mountpoint">>
                , <<"flags">>
                , <<"id">>
                , <<"payload">>
                , <<"peername">>
                , <<"topic">>
                , <<"qos">>
                , <<"timestamp">>
                ];
        'message.acked' ->
                [ <<"client_id">>
                , <<"username">>
                , <<"event">>
                , <<"flags">>
                , <<"id">>
                , <<"payload">>
                , <<"peername">>
                , <<"topic">>
                , <<"qos">>
                , <<"timestamp">>
                ];
        'message.dropped' ->
                [ <<"client_id">>
                , <<"username">>
                , <<"event">>
                , <<"flags">>
                , <<"id">>
                , <<"node">>
                , <<"payload">>
                , <<"peername">>
                , <<"qos">>
                , <<"timestamp">>
                , <<"topic">>
                ];
        'client.connected' ->
                [ <<"client_id">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"clean_start">>
                , <<"connack">>
                , <<"connected_at">>
                , <<"is_bridge">>
                , <<"keepalive">>
                , <<"mountpoint">>
                , <<"peername">>
                , <<"proto_ver">>
                ];
        'client.disconnected' ->
                [ <<"client_id">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"mountpoint">>
                , <<"peername">>
                , <<"reason_code">>
                ];
        'client.subscribe' ->
                [ <<"client_id">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"mountpoint">>
                , <<"peername">>
                , <<"topic_filters">>
                , <<"topic">>
                , <<"qos">>
                ];
        'client.unsubscribe' ->
                [ <<"client_id">>
                , <<"username">>
                , <<"event">>
                , <<"auth_result">>
                , <<"mountpoint">>
                , <<"peername">>
                , <<"topic_filters">>
                , <<"topic">>
                , <<"qos">>
                ];
        RuleType ->
                error({unknown_rule_type, RuleType})
        end).

-define(EG_ENVS(EVENT),
        case EVENT of
        'message.publish' ->
            #{event => 'message.publish',
              flags => #{dup => false,retain => false},
              from => <<"c_emqx">>,
              headers =>
                  #{allow_publish => true,
                    peername => {{127,0,0,1},50891},
                    username => <<"u_emqx">>},
              id => <<0,5,137,164,41,233,87,47,180,75,0,0,5,124,0,1>>,
              payload => <<"{\"id\": 1, \"name\": \"ha\"}">>,qos => 1,
              timestamp => erlang:timestamp(),
              topic => <<"t1">>};
        'message.deliver' ->
            #{anonymous => true,auth_result => success,
              client_id => <<"c_emqx">>,
              event => 'message.deliver',
              flags => #{dup => false,retain => false},
              from => <<"c_emqx">>,
              headers =>
                  #{allow_publish => true,
                    peername => {{127,0,0,1},50891},
                    username => <<"u_emqx">>},
              id => <<0,5,137,164,41,233,87,47,180,75,0,0,5,124,0,1>>,
              mountpoint => undefined,
              payload => <<"{\"id\": 1, \"name\": \"ha\"}">>,
              peername => {{127,0,0,1},50891},
              qos => 1,
              sockname => {{127,0,0,1},1883},
              timestamp => erlang:timestamp(),
              topic => <<"t1">>,username => <<"u_emqx">>,
              ws_cookie => undefined,zone => external};
        'message.acked' ->
            #{client_id => <<"c_emqx">>,
              event => 'message.acked',
              flags => #{dup => false,retain => false},
              from => <<"c_emqx">>,
              headers =>
                  #{allow_publish => true,
                    peername => {{127,0,0,1},50891},
                    username => <<"u_emqx">>},
              id => <<0,5,137,164,41,233,87,47,180,75,0,0,5,124,0,1>>,
              payload => <<"{\"id\": 1, \"name\": \"ha\"}">>,qos => 1,
              timestamp => erlang:timestamp(),
              topic => <<"t1">>,username => <<"u_emqx">>};
        'message.dropped' ->
            #{event => 'message.dropped',
              flags => #{dup => false,retain => false},
              from => <<"c_emqx">>,
              headers =>
                  #{allow_publish => true,
                    peername => {{127,0,0,1},50891},
                    username => <<"u_emqx">>},
              id => <<0,5,137,164,41,236,124,3,180,75,0,0,5,124,0,2>>,
              node => nonode@nohost,
              payload => <<"{\"id\": 1, \"name\": \"ha\"}">>,qos => 1,
              timestamp => erlang:timestamp(),
              topic => <<"t1">>};
        'client.connected' ->
            #{anonymous => true,auth_result => success,
              client_id => <<"c_emqx">>,
              connack => 0,
              connattrs =>
                  #{clean_start => true,
                    client_id => <<"c_emqx">>,
                    conn_mod => emqx_connection,
                    connected_at => erlang:timestamp(),
                    credentials =>
                        #{anonymous => true,auth_result => success,
                          client_id =>
                              <<"c_emqx">>,
                          mountpoint => undefined,
                          peername => {{127,0,0,1},50891},
                          sockname => {{127,0,0,1},1883},
                          username => <<"u_emqx">>,ws_cookie => undefined,
                          zone => external},
                    is_bridge => false,keepalive => 60,peercert => nossl,
                    peername => {{127,0,0,1},50891},
                    proto_name => <<"MQTT">>,proto_ver => 4,
                    username => <<"u_emqx">>,zone => external},
              event => 'client.connected',mountpoint => undefined,
              peername => {{127,0,0,1},50891},
              sockname => {{127,0,0,1},1883},
              username => <<"u_emqx">>,ws_cookie => undefined,
              zone => external};
        'client.disconnected' ->
            #{anonymous => true,auth_result => success,
              client_id => <<"c_emqx">>,
              event => 'client.disconnected',mountpoint => undefined,
              peername => {{127,0,0,1},50891},
              reason_code => closed,
              sockname => {{127,0,0,1},1883},
              username => <<"u_emqx">>,ws_cookie => undefined,
              zone => external};
        'client.subscribe' ->
            #{anonymous => true,auth_result => success,
              client_id => <<"c_emqx">>,
              event => 'client.subscribe',mountpoint => undefined,
              peername => {{127,0,0,1},50891},
              sockname => {{127,0,0,1},1883},
              topic_filters =>
                  [{<<"t1">>,#{nl => 0,qos => 1,rap => 0,rc => 1,rh => 0}}],
              username => <<"u_emqx">>,ws_cookie => undefined,
              zone => external};
        'client.unsubscribe' ->
            #{anonymous => true,auth_result => success,
              client_id => <<"c_emqx">>,
              event => 'client.unsubscribe',mountpoint => undefined,
              peername => {{127,0,0,1},50891},
              sockname => {{127,0,0,1},1883},
              topic_filters => [{<<"t1">>,#{}}],
              username => <<"u_emqx">>,ws_cookie => undefined,
              zone => external};
        RuleType ->
                error({unknown_event_type, RuleType})
        end).