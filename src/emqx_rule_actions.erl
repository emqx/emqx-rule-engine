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

-rule_action(#{name  => republish_message,
               hook  => 'message.publish',
               func  => republish_action,
               descr => "Republish messages"
              }).

-type(action_func() :: fun((Data :: map()) -> Result :: term())).

-export_type([action_func/0]).

-export([republish_action/1]).

%%------------------------------------------------------------------------------
%% Default actions for the Rule Engine
%%------------------------------------------------------------------------------

-spec(republish_action(#{from := emqx_topic:topic(),
                         to := emqx_topic:topic()})
      -> action_func()).
republish_action(#{from := From, to := To}) ->
    fun(#{message := Msg = #message{topic = Origin}}) ->
            case emqx_topic:match(Origin, From) of
                true ->
                    emqx_broker:safe_publish(Msg#message{topic = To});
                false -> ok
            end
    end.

