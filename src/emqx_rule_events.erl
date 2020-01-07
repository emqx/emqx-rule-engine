%%--------------------------------------------------------------------
%% Copyright (c) 2020 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(emqx_rule_events).

-behaviour(emqx_gen_mod).

-include("emqx.hrl").
-include("logger.hrl").

-logger_header("[RuleEvents]").

%% emqx_gen_mod callbacks
-export([ load/1
        , unload/1
        , event_name/1
        ]).

-export([ on_client_connected/3
        , on_client_disconnected/4
        , on_session_subscribed/4
        , on_session_unsubscribed/4
        , on_message_publish/2
        , on_message_dropped/4
        , on_message_delivered/3
        , on_message_acked/3
        ]).

-define(SUPPORTED_HOOK,
        [ 'client.connected'
        , 'client.disconnected'
        , 'session.subscribed'
        , 'session.unsubscribed'
        , 'message.publish'
        , 'message.delivered'
        , 'message.acked'
        , 'message.dropped'
        ]).

-ifdef(TEST).
-export([ reason/1
        , hook_fun/1]).
-endif.

load(Env) ->
    [emqx_hooks:add(HookPoint, {?MODULE, hook_fun(HookPoint), [hook_conf(HookPoint, Env)]})
     || HookPoint <- ?SUPPORTED_HOOK],
    ok.

unload(_Env) ->
    [emqx_hooks:del(HookPoint, {?MODULE, hook_fun(HookPoint)})
     || HookPoint <- ?SUPPORTED_HOOK],
    ok.

%%--------------------------------------------------------------------
%% Callbacks
%%--------------------------------------------------------------------

on_client_connected(ClientInfo, ConnInfo, Env) ->
    may_publish_and_apply(client_connected,
        eventmsg_connected(ClientInfo, ConnInfo), Env).

on_client_disconnected(ClientInfo, Reason, ConnInfo, Env) ->
    may_publish_and_apply(client_disconnected,
        eventmsg_disconnected(ClientInfo, ConnInfo, Reason), Env).

on_session_subscribed(ClientInfo, Topic, SubOpts, Env) ->
    may_publish_and_apply(session_subscribed,
        eventmsg_sub_unsub('session.subscribed', ClientInfo, Topic, SubOpts), Env).

on_session_unsubscribed(ClientInfo, Topic, SubOpts, Env) ->
    may_publish_and_apply(session_unsubscribed,
        eventmsg_sub_unsub('session.unsubscribed', ClientInfo, Topic, SubOpts), Env).

on_message_publish(Message = #message{flags = #{event := true}},
                   _Env) ->
    {ok, Message};
on_message_publish(Message = #message{flags = #{sys := true}},
                   #{ignore_sys_message := true}) ->
    {ok, Message};
on_message_publish(Message, _Env) ->
    emqx_rule_runtime:apply_rules(
        emqx_rule_registry:get_rules(), rule_input(Message)),
    {ok, Message}.

on_message_dropped(Message = #message{flags = #{sys := true}},
                   _, _, #{ignore_sys_message := true}) ->
    {ok, Message};
on_message_dropped(Message, _, Reason, Env) ->
    may_publish_and_apply(message_dropped,
        eventmsg_dropped(Message, Reason), Env),
    {ok, Message}.

on_message_delivered(_ClientInfo, Message = #message{flags = #{sys := true}},
                   #{ignore_sys_message := true}) ->
    {ok, Message};
on_message_delivered(ClientInfo, Message, Env) ->
    may_publish_and_apply(message_delivered,
        eventmsg_delivered(ClientInfo, Message), Env),
    {ok, Message}.

on_message_acked(_ClientInfo, Message = #message{flags = #{sys := true}},
                   #{ignore_sys_message := true}) ->
    {ok, Message};
on_message_acked(ClientInfo, Message, Env) ->
    may_publish_and_apply(message_acked,
        eventmsg_acked(ClientInfo, Message), Env),
    {ok, Message}.

%%--------------------------------------------------------------------
%% Event Messages
%%--------------------------------------------------------------------

eventmsg_connected(_ClientInfo = #{
                    peername := PeerName,
                    sockname := SockName,
                    clientid := ClientId,
                    username := Username,
                    is_bridge := IsBridge,
                    auth_result := AuthResult,
                    mountpoint := Mountpoint
                   },
                   _ConnInfo = #{
                    clean_start := CleanStart,
                    proto_name := ProtoName,
                    proto_ver := ProtoVer,
                    keepalive := Keepalive,
                    connected_at := ConnectedAt,
                    expiry_interval := ExpiryInterval
                   }) ->
    #{event => 'client.connected',
      clientid => ClientId,
      username => Username,
      auth_result => AuthResult,
      mountpoint => Mountpoint,
      peername => ntoa(PeerName),
      sockname => ntoa(SockName),
      proto_name => ProtoName,
      proto_ver => ProtoVer,
      keepalive => Keepalive,
      clean_start => CleanStart,
      connack => 0,
      expiry_interval => ExpiryInterval,
      is_bridge => IsBridge,
      connected_at => ConnectedAt,
      timestamp => erlang:system_time(millisecond),
      node => node()
     }.

eventmsg_disconnected(_ClientInfo = #{
                       clientid := ClientId,
                       username := Username,
                       peername := PeerName,
                       sockname := SockName
                      },
                      _ConnInfo = #{
                        disconnected_at := DisconnectedAt
                      }, Reason) ->
    #{event => 'client.disconnected',
      reason => reason(Reason),
      clientid => ClientId,
      username => Username,
      peername => ntoa(PeerName),
      sockname => ntoa(SockName),
      disconnected_at => DisconnectedAt,
      timestamp => erlang:system_time(millisecond),
      node => node()
    }.

eventmsg_sub_unsub(Event, _ClientInfo = #{
                    clientid := ClientId,
                    username := Username,
                    peername := PeerName,
                    sockname := SockName
                   }, Topic, _SubOpts = #{qos := QoS}) ->
    #{event => Event,
      clientid => ClientId,
      username => Username,
      peername => ntoa(PeerName),
      sockname => ntoa(SockName),
      topic => Topic,
      qos => QoS,
      timestamp => erlang:system_time(millisecond),
      node => node()
    }.

eventmsg_dropped(#message{id = Id, from = ClientId, qos = QoS, flags = Flags, headers = Headers, topic = Topic, payload = Payload, timestamp = Timestamp}, Reason) ->
    #{event => 'message.dropped',
      id => Id,
      reason => Reason,
      clientid => ClientId,
      username => maps:get(username, Headers, undefined),
      payload => Payload,
      peerhost => ntoa(maps:get(peerhost, Headers, undefined)),
      topic => Topic,
      qos => QoS,
      flags => Flags,
      timestamp => Timestamp,
      node => node()
    }.

eventmsg_delivered(_ClientInfo = #{
                    peername := PeerName,
                    sockname := SockName,
                    clientid := ReceiverCId,
                    username := ReceiverUsername
                  }, #message{id = Id, from = ClientId, qos = QoS, flags = Flags, topic = Topic, payload = Payload, timestamp = Timestamp, headers = Headers}) ->
    #{event => 'message.delivered',
      id => Id,
      from_clientid => ClientId,
      from_username => maps:get(username, Headers, undefined),
      clientid => ReceiverCId,
      username => ReceiverUsername,
      payload => Payload,
      peername => ntoa(PeerName),
      sockname => ntoa(SockName),
      topic => Topic,
      qos => QoS,
      flags => Flags,
      timestamp => Timestamp,
      node => node()
    }.

eventmsg_acked(_ClientInfo = #{
                    peername := PeerName,
                    sockname := SockName,
                    clientid := ReceiverCId,
                    username := ReceiverUsername
                  }, #message{id = Id, from = ClientId, qos = QoS, flags = Flags, topic = Topic, payload = Payload, timestamp = Timestamp, headers = Headers}) ->
    #{event => 'message.acked',
      id => Id,
      from_clientid => ClientId,
      from_username => maps:get(username, Headers, undefined),
      clientid => ReceiverCId,
      username => ReceiverUsername,
      payload => Payload,
      peername => ntoa(PeerName),
      sockname => ntoa(SockName),
      topic => Topic,
      qos => QoS,
      flags => Flags,
      timestamp => Timestamp,
      node => node()
    }.

%%--------------------------------------------------------------------
%% Events publishing and rules applying
%%--------------------------------------------------------------------

may_publish_and_apply(EventType, EventMsg, #{enabled := IsEnabled, qos := QoS}) ->
    case emqx_json:safe_encode(EventMsg) of
        {ok, Payload} ->
            Msg = make_msg(QoS, event_topic(EventType), Payload),
            IsEnabled andalso emqx_broker:safe_publish(Msg),
            emqx_rule_runtime:apply_rules(emqx_rule_registry:get_rules(), rule_input(Msg));
        {error, _Reason} ->
            ?LOG(error, "Failed to encode event msg for ~p, msg: ~p", [EventType, EventMsg])
    end.

make_msg(QoS, Topic, Payload) ->
    emqx_message:set_flags(#{sys => true, event => true},
        emqx_message:make(emqx_events, QoS, Topic, iolist_to_binary(Payload))).

event_topic(Name) when is_atom(Name); is_list(Name) ->
    iolist_to_binary(lists:concat(["$events/", Name]));
event_topic(Name) when is_binary(Name) ->
    iolist_to_binary(["$events/", Name]).

rule_input(#message{id = Id, from = ClientId, qos = QoS, flags = Flags, headers = Headers, topic = Topic, payload = Payload, timestamp = Timestamp}) ->
    #{id => Id,
      clientid => ClientId,
      username => maps:get(username, Headers, undefined),
      payload => Payload,
      peerhost => ntoa(maps:get(peerhost, Headers, undefined)),
      topic => Topic,
      qos => QoS,
      flags => Flags,
      timestamp => Timestamp,
      node => node()
    }.

%%--------------------------------------------------------------------
%% Helper functions
%%--------------------------------------------------------------------

hook_conf(HookPoint, Env) ->
    Events = proplists:get_value(events, Env, []),
    IgnoreSys = proplists:get_value(ignore_sys_message, Env, true),
    case lists:keyfind(HookPoint, 1, Events) of
        {_, on, QoS} -> #{enabled => true, qos => QoS, ignore_sys_message => IgnoreSys};
        _ -> #{enabled => false, qos => 1, ignore_sys_message => IgnoreSys}
    end.

hook_fun(Event) ->
    case string:split(atom_to_list(Event), ".") of
        [Prefix, Name] ->
            Point = list_to_atom(lists:append([Prefix, "_", Name])),
            list_to_atom(lists:append(["on_", Point]));
        [_] ->
            error(invalid_event, Event)
    end.

reason(Reason) when is_atom(Reason) -> Reason;
reason({shutdown, Reason}) when is_atom(Reason) -> Reason;
reason({Error, _}) when is_atom(Error) -> Error;
reason(_) -> internal_error.

ntoa(undefined) -> undefined;
ntoa({IpAddr, Port}) ->
    iolist_to_binary([inet:ntoa(IpAddr),":",integer_to_list(Port)]);
ntoa(IpAddr) ->
    iolist_to_binary(inet:ntoa(IpAddr)).

event_name(<<"$events/client_connected", _/binary>>) -> 'client.connected';
event_name(<<"$events/client_disconnected", _/binary>>) -> 'client.disconnected';
event_name(<<"$events/session_subscribed", _/binary>>) -> 'session.subscribed';
event_name(<<"$events/session_unsubscribed", _/binary>>) -> 'session.unsubscribed';
event_name(<<"$events/message_delivered", _/binary>>) -> 'message.delivered';
event_name(<<"$events/message_acked", _/binary>>) -> 'message.acked';
event_name(<<"$events/message_dropped", _/binary>>) -> 'message.dropped'.
