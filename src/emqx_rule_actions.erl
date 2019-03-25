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

-resource_type(#{name => default_resource,
                 schema => "emqx_rule_engine",
                 create => on_default_resource_create,
                 description => "Default resource"
                }).

-rule_action(#{name => inspect_action,
               for => any,
               func => inspect_action,
               params => #{},
               description => "Inspect the action for debug purpose"
              }).

-rule_action(#{name => republish_message,
               for => 'message.publish',
               func => republish_action,
               params => #{from => topic, to => topic},
               description => "Republish a MQTT message"
              }).

-type(action_fun() :: fun((Data :: map()) -> Result :: any())).

-export_type([action_fun/0]).

-export([on_default_resource_create/1]).

-export([ inspect_action/1
        , republish_action/1
        ]).

-spec(on_default_resource_create(map()) -> map()).
on_default_resource_create(Conf) ->
    Conf.

%%------------------------------------------------------------------------------
%% Default actions for the Rule Engine
%%------------------------------------------------------------------------------

-spec(inspect_action(Params :: map()) -> action_fun()).
inspect_action(Params) ->
    fun(Data) ->
        io:format("Action input data: ~p, init params: ~p~n", [Data, Params])
    end.

%% A Demo Action.
-spec(republish_action(#{from := emqx_topic:topic(),
                         to := emqx_topic:topic()})
      -> action_fun()).
republish_action(#{from := From, to := To}) ->
    fun(Msg = #{<<"topic">> := OrgTopic, <<"payload">> := Payload, <<"qos">> := QoS}) ->
            case emqx_topic:match(OrgTopic, From) of
                true ->
                    emqx_broker:safe_publish(
                        emqx_message:make(maps:get(<<"from">>, Msg, 'default:republish_action'), QoS, To, Payload));
                false -> ok
            end;
        (Args) ->
            logger:warning("No sufficent args: ~p, republish cancelled", [Args])
    end.

