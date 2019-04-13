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

-resource_type(#{name => debug_resource_type,
                 schema => "emqx_rule_engine",
                 create => on_resource_create,
                 params => #{},
                 description => "Debug resource type"
                }).

-rule_action(#{name => debug_action,
               for => any,
               func => debug_action,
               params => #{},
               description => "Debug Action"
              }).

-rule_action(#{name => republish_message,
               for => 'message.publish',
               func => republish_action,
               params => #{from => topic, to => topic},
               description => "Republish a MQTT message"
              }).

-type(action_fun() :: fun((Data :: map()) -> Result :: any())).

-export_type([action_fun/0]).

-export([on_resource_create/2]).

-export([ debug_action/1
        , republish_action/1
        ]).

%%------------------------------------------------------------------------------
%% Default actions for the Rule Engine
%%------------------------------------------------------------------------------

-spec(on_resource_create(binary(), map()) -> map()).
on_resource_create(_Name, Conf) ->
    Conf.

-spec(debug_action(Params :: map()) -> action_fun()).
debug_action(Params) ->
    fun(Data) ->
        io:format("Action input data: ~p~nAction init params: ~p~n", [Data, Params])
    end.

%% A Demo Action.
-spec(republish_action(#{from := emqx_topic:topic(),
                         to := emqx_topic:topic()})
      -> action_fun()).
republish_action(#{from := From, to := To}) ->
    fun(#{message := Msg = #message{topic = Origin}}) ->
            case emqx_topic:match(Origin, From) of
                true ->
                    emqx_broker:safe_publish(Msg#message{topic = To});
                false -> ok
            end
    end.

