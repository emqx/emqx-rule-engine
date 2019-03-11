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
%%
%% @doc External Resource Manager:
%%
%%                Supervisor
%%                    |
%%                   \|/
%% Action ----> Proxy(Batch|Write) ----> Connection -----> ExternalResource
%%   |                                      /|\
%%   |---------------- Fetch ----------------|
%%
%% @end

-module(emqx_resource_mgr).

-include("rule_engine.hrl").
-include_lib("emqx/include/types.hrl").
-include_lib("emqx/include/logger.hrl").

-behaviour(gen_server).

-export([start_link/0]).

%% Core API
-export([fetch/2,
         write/2
        ]).

%% Management API
-export([create/2,
         bind/2,
         lookup/1,
         list/0,
         unbind/1,
         delete/1
        ]).

%% Resource Type API
-export([register_type/2,
         unregister_type/1
        ]).

%% gen_server Callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

%% Mnesia bootstrap
-export([mnesia/1]).

-boot_mnesia({mnesia, [boot]}).
-copy_mnesia({mnesia, [copy]}).

-type(resource_name() :: {atom(), node()}).

-record(state, {}).

-define(SERVER, ?MODULE).
-define(RES_TAB, emqx_resource).
-define(RES_TYPE_TAB, emqx_resource_type).

%%------------------------------------------------------------------------------
%% Mnesia bootstrap
%%------------------------------------------------------------------------------

-spec(mnesia(boot | copy) -> ok).
mnesia(boot) ->
    %% Resource table
    ok = ekka_mnesia:create_table(?RES_TAB, [
                {disc_copies, [node()]},
                {record_name, resource},
                {index, [#resource.type]},
                {attributes, record_info(fields, resource)},
                {storage_properties, [{ets, [{read_concurrency, true}]}]}]),
    %% Resource type table
    ok = ekka_mnesia:create_table(?RES_TYPE_TAB, [
                {ram_copies, [node()]},
                {record_name, resource_type},
                {attributes, record_info(fields, resource_type)}]);

mnesia(copy) ->
    %% Copy resource table
    ok = ekka_mnesia:copy_table(?RES_TAB),
    %% Copy resource type table
    ok = ekka_mnesia:copy_table(?RES_TYPE_TAB).

-spec(start_link() -> startlink_ret()).
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%------------------------------------------------------------------------------
%% Core API
%%------------------------------------------------------------------------------

-spec(fetch(resource_name(), Args :: list(any())) -> any()).
fetch(Name, Args) ->
    with_resource(Name, fun(#resource{fetch = Fetch}) -> erlang:apply(Fetch, Args) end).

-spec(write(resource_name(), list(any())) -> any()).
write(Name, Args) ->
    with_resource(Name, fun(#resource{write = Write}) -> erlang:apply(Write, Args) end).

%% @private
with_resource(Name, Action) ->
    case lookup(Name) of
        {ok, Resource} -> Action(Resource);
        not_found -> error(resource_not_found)
    end.

%%------------------------------------------------------------------------------
%% Resource Management API
%%------------------------------------------------------------------------------

create(Type, Params) ->
    ok.

bind(Name, Conn) ->
    gen_server:cast(?SERVER, {bind, Name, Conn}).

lookup(Name) ->
    {ok, "resource"}.

%% @doc List all resources.
list() ->
    [].

%% @doc List all resources of the type.
list(Type) ->
    mnesia:dirty_index_read(?RES_TAB, Type, #resource.type).

unbind(Name, Conn) ->
    gen_server:cast(?SERVER, {unbind, Name, Conn}).

delete(Name) ->
    mnesia:dirty_delete(?RES_TAB, {Name, node()}).

%%------------------------------------------------------------------------------
%% Resource Type API
%%------------------------------------------------------------------------------

register_type(App, Name) ->
    ok.

unregister_type(Name) ->
    ok.

%%------------------------------------------------------------------------------
%% gen_server callbacks
%%------------------------------------------------------------------------------

init([]) ->
    {ok, #{}}.

handle_call({bind, Name, Conn}, _From, State) ->
    {reply, ok, State};

handle_call(Req, _From, State) ->
    ?LOG(error, "[ResourceMgr] unexpected call: ~p", [Req]),
    {reply, ignored, State}.

handle_cast({bind, Name, Conn}, State) ->
    {reply, ok, State};

handle_cast(Msg, State) ->
    ?LOG(error, "[ResourceMgr] unexpected cast: ~p", [Msg]),
    {noreply, State}.

handle_info(Info, State) ->
    ?LOG(error, "[ResourceMgr] unexpected info: ~p", [Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%------------------------------------------------------------------------------
%% Internal functions
%%------------------------------------------------------------------------------


