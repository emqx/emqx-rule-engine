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
-include_lib("emqx/include/logger.hrl").

-define(REPUBLISH_PARAMS_SPEC, #{
            target_topic => #{
                type => string,
                format => topic,
                required => true,
                title => <<"To Which Topic">>,
                description => <<"Repubilsh the message to which topic">>
            }
        }).

-resource_type(#{name => built_in,
                 create => on_resource_create,
                 params => #{},
                 title => <<"Built-In Resource Type">>,
                 description => "The built in resource type for debug purpose"
                }).

-rule_action(#{name => inspect,
               for => '$any',
               type => built_in,
               func => inspect,
               params => #{},
               title => <<"Inspect Action">>,
               description => <<"Inspect the details of action params for debug purpose">>
              }).

-rule_action(#{name => republish,
               for => 'message.publish',
               type => built_in,
               func => republish,
               params => ?REPUBLISH_PARAMS_SPEC,
               title => <<"Republish Action">>,
               description => "Republish a MQTT message to a another topic"
              }).

-type(action_fun() :: fun((SelectedData::map(), Envs::map()) -> Result::any())).

-export_type([action_fun/0]).

-export([on_resource_create/2]).

-export([ inspect/1
        , republish/1
        ]).

%%------------------------------------------------------------------------------
%% Default actions for the Rule Engine
%%------------------------------------------------------------------------------

-spec(on_resource_create(binary(), map()) -> map()).
on_resource_create(_Name, Conf) ->
    Conf.

-spec(inspect(Params :: map()) -> action_fun()).
inspect(Params) ->
    fun(Selected, Envs) ->
        io:format("[inspect]~n"
                  "\tSelected Data: ~p~n"
                  "\tEnvs: ~p~n"
                  "\tAction Init Params: ~p~n", [Selected, Envs, Params])
    end.

%% A Demo Action.
-spec(republish(#{binary() := emqx_topic:topic()})
      -> action_fun()).
republish(#{<<"target_topic">> := TargetTopic}) ->
    fun(Selected, #{qos := QoS, client_id := Client,
                    flags := Flags, headers := Headers}) ->
        ?LOG(debug, "[republish] republish to: ~p, Payload: ~p",
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
            })
    end.

republish_from(Client) ->
    C = bin(Client), <<"built_in:republish:", C/binary>>.

bin(Bin) when is_binary(Bin) -> Bin;
bin(Atom) when is_atom(Atom) ->
    list_to_binary(atom_to_list(Atom));
bin(Str) when is_list(Str) -> list_to_binary(Str).