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

-include_lib("emqx/include/emqx.hrl").

-define(REPUBLISH_PARAMS_SPEC, #{
            from => #{type => string,
                      format => topic,
                      required => true,
                      description => <<"From which topic">>},
            to => #{type => string,
                    format => topic,
                    required => true,
                    description => <<"Repubilsh To which topic">>}
        }).

-resource_type(#{name => built_in,
                 create => on_resource_create,
                 params => #{},
                 description => "Debug resource type"
                }).

-rule_action(#{name => inspect_action,
               for => '$any',
               type => built_in,
               func => inspect_action,
               params => #{},
               description => "Debug Action"
              }).

-rule_action(#{name => republish_action,
               for => 'message.publish',
               type => built_in,
               func => republish_action,
               params => ?REPUBLISH_PARAMS_SPEC,
               description => "Republish a MQTT message"
              }).

-type(action_fun() :: fun((SelectedData::map(), Envs::map()) -> Result::any())).

-export_type([action_fun/0]).

-export([on_resource_create/2]).

-export([ inspect_action/1
        , republish_action/1
        ]).

%%------------------------------------------------------------------------------
%% Default actions for the Rule Engine
%%------------------------------------------------------------------------------

-spec(on_resource_create(binary(), map()) -> map()).
on_resource_create(_Name, Conf) ->
    Conf.

-spec(inspect_action(Params :: map()) -> action_fun()).
inspect_action(Params) ->
    fun(Selected, Envs) ->
        io:format("[built_in:inspect_action]~n"
                  "\tSelected Data: ~p~n"
                  "\tEnvs: ~p~n"
                  "\tAction Init Params: ~p~n", [Selected, Envs, Params])
    end.

%% A Demo Action.
-spec(republish_action(#{from := emqx_topic:topic(),
                         to := emqx_topic:topic()})
      -> action_fun()).
republish_action(#{from := SrcTopic, to := TargetTopic}) ->
    fun(Selected, #{topic := OriginTopic, qos := QoS, from := Client,
                    flags := Flags, headers := Headers}) ->
            case emqx_topic:match(OriginTopic, SrcTopic) of
                true ->
                    logger:debug("[built_in:republish_action] republish to: ~p, Payload: ~p",
                                 [TargetTopic, Selected]),
                    emqx_broker:safe_publish(
                        #message{
                            id = emqx_guid:gen(),
                            qos = QoS,
                            from = republish_from(Client),
                            flags = Flags,
                            headers = Headers,
                            topic = TargetTopic,
                            payload = jsx:encode(Selected),
                            timestamp = erlang:timestamp()
                        });
                false -> ok
            end
    end.

republish_from(Client) ->
    C = bin(Client), <<"built_in:republish_action:", C/binary>>.

bin(Bin) when is_binary(Bin) -> Bin;
bin(Atom) when is_atom(Atom) ->
    list_to_binary(atom_to_list(Atom));
bin(Str) when is_list(Str) -> list_to_binary(Str).