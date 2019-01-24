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

-module(emqx_rule_store).

-include("emqx_rule_engine.hrl").

%% Mnesia tables
-define(RULE, emqx_rule).
-define(ACTION, emqx_rule_action).

-export([mnesia/1]).

%%------------------------------------------------------------------------------
%% Mnesia bootstrap
%%------------------------------------------------------------------------------

%% @doc Create or replicate trie tables.
-spec(mnesia(boot | copy) -> ok).
mnesia(boot) ->
    %% Optimize storage
    StoreProps = [{ets, [{read_concurrency, true}]}],
    %% Rule table
    ok = ekka_mnesia:create_table(?RULE, [
                {disc_copies, [node()]},
                {record_name, rule},
                {attributes, record_info(fields, rule)},
                {storage_properties, StoreProps}]),
    %% Rule action table
    ok = ekka_mnesia:create_table(?ACTION, [
                {disc_copies, [node()]},
                {record_name, action},
                {attributes, record_info(fields, action)},
                {storage_properties, StoreProps}]);

mnesia(copy) ->
    %% Copy rule table
    ok = ekka_mnesia:copy_table(?RULE),
    %% Copy rule action table
    ok = ekka_mnesia:copy_table(?ACTION).

