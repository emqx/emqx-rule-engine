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
          name :: binary(),
          hook :: atom(),
          topic :: binary(),
          conditions :: list(),
          actions :: list({atom(), Args :: list()}),
          enabled :: boolean(),
          description :: string()
         }).

-record(action, {
          id :: atom(),
          name :: atom(),
          for :: atom(),
          app :: atom(),
          module :: module(),
          func :: atom(),
          params :: #{atom() := term()},
          description :: binary() | string()
         }).

-record(resource, {
          name :: {string(), node()},
          type :: atom(), %% Resource Type
          config :: #{},
          request :: fun(),
          conns :: list(pid()) | undefined,
          attrs :: #{},
          description :: binary()
         }).

-record(resource_type, {
          name :: atom(),
          provider :: atom(),
          params :: #{},
          create :: fun(),
          connect :: fun() | undefined,
          disconnect :: fun() | undefined,
          description :: binary()
        }).

