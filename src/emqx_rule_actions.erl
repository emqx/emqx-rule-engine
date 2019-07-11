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

%% Define the default actions.
-module(emqx_rule_actions).

-include("rule_engine.hrl").
-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").

-define(REPUBLISH_PARAMS_SPEC, #{
            target_topic => #{
                order => 1,
                type => string,
                required => true,
                default => <<"resp/${client_id}">>,
                title => #{en => <<"Target Topic">>,
                           zh => <<"目的主题"/utf8>>},
                description => #{en => <<"To which topic the message will be republished">>,
                                 zh => <<"重新发布消息到哪个主题"/utf8>>}
            },
            payload_tmpl => #{
                order => 2,
                type => string,
                input => textarea,
                required => true,
                default => <<"${payload}">>,
                title => #{en => <<"Payload Template">>,
                           zh => <<"消息内容模板"/utf8>>},
                description => #{en => <<"The payload template, variable interpolation is supported">>,
                                 zh => <<"消息内容模板，支持变量"/utf8>>}
            }
        }).

-rule_action(#{name => inspect,
               for => '$any',
               types => [],
               create => on_action_create_inspect,
               params => #{},
               title => #{en => <<"Inspect (debug)">>,
                          zh => <<"检查 (调试)"/utf8>>},
               description => #{en => <<"Inspect the details of action params for debug purpose">>,
                                zh => <<"检查动作参数 (用以调试)"/utf8>>}
              }).

-rule_action(#{name => republish,
               for => 'message.publish',
               types => [],
               create => on_action_create_republish,
               params => ?REPUBLISH_PARAMS_SPEC,
               title => #{en => <<"Republish">>,
                          zh => <<"消息重新发布"/utf8>>},
               description => #{en => <<"Republish a MQTT message to another topic">>,
                                zh => <<"重新发布消息到另一个主题"/utf8>>}
              }).

-rule_action(#{name => do_nothing,
               for => '$any',
               types => [],
               create => on_action_do_nothing,
               params => #{},
               title => #{en => <<"Do Nothing (debug)">>,
                          zh => <<"空动作 (调试)"/utf8>>},
               description => #{en => <<"This action does nothing and never fails. It's for debug purpose">>,
                                zh => <<"此动作什么都不做，并且不会失败 (用以调试)"/utf8>>}
              }).

-type(action_fun() :: fun((SelectedData::map(), Envs::map()) -> Result::any())).

-export_type([action_fun/0]).

-export([on_resource_create/2]).

-export([ on_action_create_inspect/2
        , on_action_create_republish/2
        , on_action_do_nothing/2
        ]).

%%------------------------------------------------------------------------------
%% Default actions for the Rule Engine
%%------------------------------------------------------------------------------

-spec(on_resource_create(binary(), map()) -> map()).
on_resource_create(_Name, Conf) ->
    Conf.

-spec(on_action_create_inspect(action_instance_id(), Params :: map()) -> action_fun()).
on_action_create_inspect(_Id, Params) ->
    fun(Selected, Envs) ->
        io:format("[inspect]~n"
                  "\tSelected Data: ~p~n"
                  "\tEnvs: ~p~n"
                  "\tAction Init Params: ~p~n", [Selected, Envs, Params])
    end.

%% A Demo Action.
-spec(on_action_create_republish(action_instance_id(), #{binary() := emqx_topic:topic()})
      -> action_fun()).
on_action_create_republish(_Id, #{<<"target_topic">> := TargetTopic, <<"payload_tmpl">> := PayloadTmpl}) ->
    fun(Selected, #{qos := QoS, from := Client,
                    flags := Flags, headers := Headers}) ->
        ?LOG(debug, "[republish] republish to: ~p, Payload: ~p",
                        [TargetTopic, Selected]),
        TopicTks = emqx_rule_utils:preproc_tmpl(TargetTopic),
        PayloadTks = emqx_rule_utils:preproc_tmpl(PayloadTmpl),
        emqx_broker:safe_publish(
            #message{
                id = emqx_guid:gen(),
                qos = QoS,
                from = republish_from(Client),
                flags = Flags,
                headers = Headers,
                topic = emqx_rule_utils:proc_tmpl(TopicTks, Selected),
                payload = emqx_rule_utils:proc_tmpl(PayloadTks, Selected),
                timestamp = erlang:timestamp()
            })
    end.

on_action_do_nothing(_, _) ->
    fun(_, _) -> ok end.

republish_from(Client) ->
    C = bin(Client), <<"action:republish:", C/binary>>.

bin(Bin) when is_binary(Bin) -> Bin;
bin(Atom) when is_atom(Atom) ->
    list_to_binary(atom_to_list(Atom));
bin(Str) when is_list(Str) -> list_to_binary(Str).