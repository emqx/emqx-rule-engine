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
        ]).

-export([ on_client_connected/3
        , on_client_disconnected/4
        , on_session_subscribed/4
        , on_session_unsubscribed/4
        , on_message_publish/2
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
        event_msg_connected(ClientInfo, ConnInfo), Env).

on_client_disconnected(ClientInfo, Reason, ConnInfo, Env) ->
    may_publish_and_apply(client_disconnected,
        event_msg_disconnected(ClientInfo, ConnInfo, Reason), Env).

on_session_subscribed(ClientInfo, Topic, SubOpts, Env) ->
    may_publish_and_apply(session_subscribed,
        event_msg_subscribed(ClientInfo, Topic, SubOpts), Env).

on_session_unsubscribed(ClientInfo, Topic, SubOpts, Env) ->
    may_publish_and_apply(session_unsubscribed,
        event_msg_subscribed(ClientInfo, Topic, SubOpts), Env).

on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>},
                   #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_publish(Message, _Env) ->
    emqx_rule_runtime:apply_rules(emqx_rule_registry:get_rules(), rule_input(Message)),
    {ok, Message}.

on_message_dropped(Message = #message{topic = <<"$SYS/", _/binary>>},
                   _, _, #{ignore_sys_message := true}) ->
    {ok, Message};

on_message_dropped(Message, _, _, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(emqx_message:to_map(Message), #{event => 'message.dropped', node => node()})),
    {ok, Message}.

on_message_deliver(ClientInfo, Message, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(ClientInfo#{event => 'message.delivered', node => node()}, emqx_message:to_map(Message))),
    {ok, Message}.

on_message_acked(_ClientInfo, Message, #{apply_fun := ApplyRules}) ->
    ApplyRules(maps:merge(emqx_message:to_map(Message), #{event => 'message.acked', node => node()})),
    {ok, Message}.

%%--------------------------------------------------------------------
%% Helper functions
%%--------------------------------------------------------------------

event_msg_disconnected(_ClientInfo = #{clientid := ClientId, username := Username},
                       _ConnInfo = #{disconnected_at := DisconnectedAt},
                       Reason) ->
    #{clientid => ClientId,
      username => Username,
      reason => reason(Reason),
      disconnected_at => DisconnectedAt,
      timestamp => erlang:system_time(millisecond)}.

event_msg_connected(_ClientInfo = #{
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
    #{clientid => ClientId,
      username => Username,
      node => node(),
      peername => ntoa(PeerName),
      sockname => ntoa(SockName),
      proto_name => ProtoName,
      proto_ver => ProtoVer,
      keepalive => Keepalive,
      connack => 0, %% Deprecated?
      clean_start => CleanStart,
      expiry_interval => ExpiryInterval,
      connected_at => ConnectedAt,
      is_bridge => IsBridge,
      auth_result => AuthResult,
      mountpoint => Mountpoint,
      timestamp => erlang:system_time(millisecond)
     }.

event_msg_subscribed(_ClientInfo = #{
                        clientid := ClientId,
                        username := Username
                    }, Topic, _SubOpts = #{qos := QoS}) ->
    #{clientid => ClientId,
      username => Username,
      topic => Topic,
      qos => QoS
    }.

may_publish_and_apply(EventType, EventMsg, #{enabled := true, qos := QoS}) ->
    case emqx_json:safe_encode(EventMsg) of
        {ok, Payload} ->
            Msg = make_msg(QoS, event_topic(EventType), Payload),
            emqx_broker:safe_publish(Msg),
            emqx_rule_runtime:apply_rules(emqx_rule_registry:get_rules(), rule_input(Msg));
        {error, _Reason} ->
            ?LOG(error, "Failed to encode event msg for ~p, msg: ~p", [EventType, EventMsg])
    end;
may_publish_and_apply(_EventType, _EventMsg, _Env) ->
    ok.

make_msg(QoS, Topic, Payload) ->
    emqx_message:set_flag(
      sys, emqx_message:make(?MODULE, QoS, Topic, iolist_to_binary(Payload))).

event_topic(Name) when is_atom(Name); is_list(Name) ->
    iolist_to_binary(lists:concat(["$events/", Name]));
event_topic(Name) when is_binary(Name) ->
    iolist_to_binary(["$events/", Name]).

rule_input(Message) ->
    Headers = emqx_message:headers(Message),
    Username = maps:get(username, Headers, undefined),
    PeerHost = maps:get(peerhost, Headers, undefined),
    #{id => emqx_message:id(Message),
      clientid => emqx_message:from(Message),
      username => Username,
      payload => emqx_message:payload(Message),
      peerhost => ntoa(PeerHost),
      topic => emqx_message:topic(Message),
      qos => emqx_message:qos(Message),
      timestamp => emqx_message:timestamp(Message)
    }.


hook_conf(HookPoint, Env) ->
    Events = proplists:get_value(events, Env, []),
    IgnoreSys = proplists:get_value(ignore_sys_message, Env, true),
    case lists:keyfind(HookPoint, 1, Events) of
        {_, on, QoS} -> #{enabled => true, qos => QoS, ignore_sys_message => IgnoreSys};
        _ -> #{enabled => false, ignore_sys_message => IgnoreSys}
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

ntoa({IpAddr, Port}) ->
    iolist_to_binary([inet:ntoa(IpAddr),":",integer_to_list(Port)]);
ntoa(IpAddr) ->
    iolist_to_binary(inet:ntoa(IpAddr)).