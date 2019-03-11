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

-record(rule, {
          id :: binary(),
          hook :: atom(),
          name,
          topic,
          conditions,
          action,
          args,
          enabled
         }).

-record(action, {
          id :: atom(),
          name :: atom(),
          for :: atom(),
          app :: atom(),
          module :: module(),
          func :: atom(),
          params :: #{atom() := atom()},
          descr :: binary() | string()
         }).

-record(resource, {
          name :: {atom(), node()},
          type :: atom(),
          config :: #{},
          fetch :: fun(),
          write :: fun(),
          state :: running | stopped,
          conns :: list(pid()) | undefined,
          descr :: string()
         }).

-record(resource_type, {
          name :: atom(),
          params :: #{},
          validate :: fun(),
          create :: fun(),
          descr :: string()
        }).

