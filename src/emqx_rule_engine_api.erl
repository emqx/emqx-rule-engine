%%--------------------------------------------------------------------
%% Copyright (c) 2020 EMQ Technologies Co., Ltd. All Rights Reserved.
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
%%--------------------------------------------------------------------

-module(emqx_rule_engine_api).

-include("rule_engine.hrl").
-include("rule_events.hrl").
-include_lib("emqx/include/logger.hrl").

-import(minirest,  [return/1]).

-rest_api(#{name   => create_rule,
            method => 'POST',
            path   => "/rules/",
            func   => create_rule,
            descr  => "Create a rule"
           }).

-rest_api(#{name   => update_rule,
            method => 'PUT',
            path   => "/rules/:bin:id",
            func   => update_rule,
            descr  => "Update a rule"
           }).

-rest_api(#{name   => list_rules,
            method => 'GET',
            path   => "/rules/",
            func   => list_rules,
            descr  => "A list of all rules"
           }).

-rest_api(#{name   => show_rule,
            method => 'GET',
            path   => "/rules/:bin:id",
            func   => show_rule,
            descr  => "Show a rule"
           }).

-rest_api(#{name   => delete_rule,
            method => 'DELETE',
            path   => "/rules/:bin:id",
            func   => delete_rule,
            descr  => "Delete a rule"
           }).

-rest_api(#{name   => list_actions,
            method => 'GET',
            path   => "/actions/",
            func   => list_actions,
            descr  => "A list of all actions"
           }).

-rest_api(#{name   => show_action,
            method => 'GET',
            path   => "/actions/:atom:name",
            func   => show_action,
            descr  => "Show an action"
           }).

-rest_api(#{name   => list_resources,
            method => 'GET',
            path   => "/resources/",
            func   => list_resources,
            descr  => "A list of all resources"
           }).

-rest_api(#{name   => create_resource,
            method => 'POST',
            path   => "/resources/",
            func   => create_resource,
            descr  => "Create a resource"
           }).

-rest_api(#{name   => show_resource,
            method => 'GET',
            path   => "/resources/:bin:id",
            func   => show_resource,
            descr  => "Show a resource"
           }).

-rest_api(#{name   => get_resource_status,
            method => 'GET',
            path   => "/resource_status/:bin:id",
            func   => get_resource_status,
            descr  => "Get status of a resource"
           }).

-rest_api(#{name   => start_resource,
            method => 'POST',
            path   => "/resources/:bin:id",
            func   => start_resource,
            descr  => "Start a resource"
           }).

-rest_api(#{name   => delete_resource,
            method => 'DELETE',
            path   => "/resources/:bin:id",
            func   => delete_resource,
            descr  => "Delete a resource"
           }).

-rest_api(#{name   => list_resource_types,
            method => 'GET',
            path   => "/resource_types/",
            func   => list_resource_types,
            descr  => "List all resource types"
           }).

-rest_api(#{name   => show_resource_type,
            method => 'GET',
            path   => "/resource_types/:atom:name",
            func   => show_resource_type,
            descr  => "Show a resource type"
           }).

-rest_api(#{name   => list_resources_by_type,
            method => 'GET',
            path   => "/resource_types/:atom:type/resources",
            func   => list_resources_by_type,
            descr  => "List all resources of a resource type"
           }).

-rest_api(#{name   => list_events,
            method => 'GET',
            path   => "/rule_events/",
            func   => list_events,
            descr  => "List all events with detailed info"
           }).

-export([ create_rule/2
        , update_rule/2
        , list_rules/2
        , show_rule/2
        , delete_rule/2
        ]).

-export([ list_actions/2
        , show_action/2
        ]).

-export([ create_resource/2
        , list_resources/2
        , show_resource/2
        , get_resource_status/2
        , start_resource/2
        , delete_resource/2
        ]).

-export([ list_resource_types/2
        , list_resources_by_type/2
        , show_resource_type/2
        ]).

-export([list_events/2]).

-define(ERR_NO_RULE(ID), list_to_binary(io_lib:format("Rule ~s Not Found", [(ID)]))).
-define(ERR_NO_ACTION(NAME), list_to_binary(io_lib:format("Action ~s Not Found", [(NAME)]))).
-define(ERR_NO_RESOURCE(RESID), list_to_binary(io_lib:format("Resource ~s Not Found", [(RESID)]))).
-define(ERR_NO_HOOK(HOOK), list_to_binary(io_lib:format("Event ~s Not Found", [(HOOK)]))).
-define(ERR_NO_RESOURCE_TYPE(TYPE), list_to_binary(io_lib:format("Resource Type ~s Not Found", [(TYPE)]))).
-define(ERR_UNKNOWN_COLUMN(COLUMN), list_to_binary(io_lib:format("Unknown Column: ~s", [(COLUMN)]))).
-define(ERR_START_RESOURCE(RESID), list_to_binary(io_lib:format("Start Resource ~s Failed", [(RESID)]))).
-define(ERR_BADARGS(REASON),
        begin
            R0 = list_to_binary(io_lib:format("~0p", [REASON])),
            <<"Bad Arguments: ", R0/binary>>
        end).

%%------------------------------------------------------------------------------
%% Rules API
%%------------------------------------------------------------------------------
create_rule(_Bindings, Params) ->
    if_test(fun() -> test_rule_sql(Params) end,
            fun() -> do_create_rule(Params) end,
            Params).

test_rule_sql(Params) ->
    try emqx_rule_sqltester:test(emqx_json:decode(emqx_json:encode(Params), [return_maps])) of
        {ok, Result} -> return({ok, Result});
        {error, nomatch} -> return({error, 404, <<"SQL Not Match">>})
    catch
        throw:{invalid_hook, Hook} ->
            return({error, 400, ?ERR_NO_HOOK(Hook)});
        throw:Reason ->
            return({error, 400, ?ERR_BADARGS(Reason)});
        _:{parse_error,{unknown_column, Column}, _} ->
            return({error, 400, ?ERR_UNKNOWN_COLUMN(Column)});
        _Error:Reason:StackT ->
            ?LOG(error, "[RuleEngineAPI] ~p failed: ~0p", [?FUNCTION_NAME, {Reason, StackT}]),
            return({error, 400, ?ERR_BADARGS(Reason)})
    end.

do_create_rule(Params) ->
    try emqx_rule_engine:create_rule(parse_rule_params(Params)) of
        {ok, Rule} ->
            return({ok, record_to_map(Rule)});
        {error, {action_not_found, ActionName}} ->
            return({error, 400, ?ERR_NO_ACTION(ActionName)})
    catch
        throw:{resource_not_found, ResId} ->
            return({error, 400, ?ERR_NO_RESOURCE(ResId)});
        throw:{invalid_hook, Hook} ->
            return({error, 400, ?ERR_NO_HOOK(Hook)});
        throw:Reason ->
            return({error, 400, ?ERR_BADARGS(Reason)});
        _:{parse_error,{unknown_column, Column}} ->
            return({error, 400, ?ERR_UNKNOWN_COLUMN(Column)});
        _Error:Reason:StackT ->
            ?LOG(error, "[RuleEngineAPI] ~p failed: ~0p", [?FUNCTION_NAME, {Reason, StackT}]),
            return({error, 400, ?ERR_BADARGS(Reason)})
    end.

update_rule(#{id := Id}, Params) ->
    try emqx_rule_engine:update_rule(parse_rule_params(Params, #{id => Id})) of
        {ok, Rule} ->
            return({ok, record_to_map(Rule)});
        {error, {not_found, RuleId}} ->
            return({error, 400, ?ERR_NO_RULE(RuleId)});
        {error, {action_not_found, ActionName}} ->
            return({error, 400, ?ERR_NO_ACTION(ActionName)})
    catch
        throw:{resource_not_found, ResId} ->
            return({error, 400, ?ERR_NO_RESOURCE(ResId)});
        throw:{invalid_hook, Hook} ->
            return({error, 400, ?ERR_NO_HOOK(Hook)});
        throw:Reason ->
            return({error, 400, ?ERR_BADARGS(Reason)});
        _:{parse_error,{unknown_column, Column}} ->
            return({error, 400, ?ERR_UNKNOWN_COLUMN(Column)});
        _Error:Reason:StackT ->
            ?LOG(error, "[RuleEngineAPI] ~p failed: ~0p", [?FUNCTION_NAME, {Reason, StackT}]),
            return({error, 400, ?ERR_BADARGS(Reason)})
    end.

list_rules(_Bindings, _Params) ->
    return_all(emqx_rule_registry:get_rules()).

show_rule(#{id := Id}, _Params) ->
    reply_with(fun emqx_rule_registry:get_rule/1, Id).

delete_rule(#{id := Id}, _Params) ->
    ok = emqx_rule_engine:delete_rule(Id),
    return(ok).

%%------------------------------------------------------------------------------
%% Actions API
%%------------------------------------------------------------------------------

list_actions(#{}, _Params) ->
    return_all(emqx_rule_registry:get_actions()).

show_action(#{name := Name}, _Params) ->
    reply_with(fun emqx_rule_registry:find_action/1, Name).

%%------------------------------------------------------------------------------
%% Resources API
%%------------------------------------------------------------------------------
create_resource(#{}, Params) ->
    if_test(fun() -> do_create_resource(test_resource, Params) end,
            fun() -> do_create_resource(create_resource, Params) end,
            Params).

do_create_resource(Create, Params) ->
    try emqx_rule_engine:Create(parse_resource_params(Params)) of
        ok ->
            return(ok);
        {ok, Resource} ->
            return({ok, record_to_map(Resource)});
        {error, {resource_type_not_found, Type}} ->
            return({error, 400, ?ERR_NO_RESOURCE_TYPE(Type)})
    catch
        throw:{resource_type_not_found, Type} ->
            return({error, 400, ?ERR_NO_RESOURCE_TYPE(Type)});
        throw:{init_resource_failure, Reason} ->
            %% only test_resource would throw exceptions, create_resource won't
            ?LOG(error, "[RuleEngineAPI] test_resource_failure: ~p", [Reason]),
            return({error, 500, <<"Test Creating Resource Failed">>});
        throw:Reason ->
            return({error, 400, ?ERR_BADARGS(Reason)});
        _Error:Reason:StackT ->
            ?LOG(error, "[RuleEngineAPI] ~p failed: ~0p", [?FUNCTION_NAME, {Reason, StackT}]),
            return({error, 400, ?ERR_BADARGS(Reason)})
    end.

list_resources(#{}, _Params) ->
    return_all(emqx_rule_registry:get_resources()).

list_resources_by_type(#{type := Type}, _Params) ->
    return_all(emqx_rule_registry:get_resources_by_type(Type)).

show_resource(#{id := Id}, _Params) ->
    case emqx_rule_registry:find_resource(Id) of
        {ok, R} ->
            Status =
                [begin
                    {ok, St} = rpc:call(Node, emqx_rule_engine, get_resource_status, [Id]),
                    maps:put(node, Node, St)
                end || Node <- [node()| nodes()]],
            return({ok, maps:put(status, Status, record_to_map(R))});
        not_found ->
            return({error, 404, <<"Not Found">>})
    end.

get_resource_status(#{id := Id}, _Params) ->
    case emqx_rule_engine:get_resource_status(Id) of
        {ok, Status} ->
            return({ok, Status});
        {error, {resource_not_found, ResId}} ->
            return({error, 400, ?ERR_NO_RESOURCE(ResId)})
    end.

start_resource(#{id := Id}, _Params) ->
    try emqx_rule_engine:start_resource(Id) of
        ok ->
            return(ok);
        {error, {resource_not_found, ResId}} ->
            return({error, 400, ?ERR_NO_RESOURCE(ResId)})
    catch
        throw:{{init_resource_failure, _}, Reason} ->
            ?LOG(error, "[RuleEngineAPI] init_resource_failure: ~p", [Reason]),
            return({error, 400, ?ERR_START_RESOURCE(Id)});
        throw:Reason ->
            return({error, 400, ?ERR_BADARGS(Reason)});
        _Error:Reason:StackT ->
            ?LOG(error, "[RuleEngineAPI] ~p failed: ~0p", [?FUNCTION_NAME, {Reason, StackT}]),
            return({error, 400, ?ERR_BADARGS(Reason)})
    end.

delete_resource(#{id := Id}, _Params) ->
    try
        emqx_rule_engine:delete_resource(Id),
        return(ok)
    catch
        _Error:{throw,Reason} ->
            return({error, 400, ?ERR_BADARGS(Reason)});
        throw:Reason ->
            return({error, 400, ?ERR_BADARGS(Reason)});
        _Error:Reason:StackT ->
            ?LOG(error, "[RuleEngineAPI] ~p failed: ~0p", [?FUNCTION_NAME, {Reason, StackT}]),
            return({error, 400, ?ERR_BADARGS(Reason)})
    end.

%%------------------------------------------------------------------------------
%% Resource Types API
%%------------------------------------------------------------------------------

list_resource_types(#{}, _Params) ->
    return_all(
        sort_by_title(resource_type,
            emqx_rule_registry:get_resource_types())).

show_resource_type(#{name := Name}, _Params) ->
    reply_with(fun emqx_rule_registry:find_resource_type/1, Name).


%%------------------------------------------------------------------------------
%% Events API
%%------------------------------------------------------------------------------

list_events(#{}, _Params) ->
    return({ok, ?EVENT_INFO}).

%%------------------------------------------------------------------------------
%% Internal functions
%%------------------------------------------------------------------------------

if_test(True, False, Params) ->
    case proplists:get_value(<<"test">>, Params) of
        Test when Test =:= true; Test =:= <<"true">> ->
            True();
        _ ->
            False()
    end.

return_all(Records) ->
    Data = lists:foldr(fun maybe_record_to_map/2, [], Records),
    return({ok, Data}).

maybe_record_to_map(Rec, Acc) ->
    case record_to_map(Rec) of
        ignore -> Acc;
        Map -> [Map | Acc]
    end.

reply_with(Find, Key) ->
    case Find(Key) of
        {ok, R} ->
            return({ok, record_to_map(R)});
        not_found ->
            return({error, 404, <<"Not Found">>})
    end.

record_to_map(#rule{id = Id,
                    for = Hook,
                    rawsql = RawSQL,
                    actions = Actions,
                    on_action_failed = OnFailed,
                    enabled = Enabled,
                    description = Descr}) ->
    #{id => Id,
      for => Hook,
      rawsql => RawSQL,
      actions => printable_actions(Actions),
      on_action_failed => OnFailed,
      metrics => get_rule_metrics(Id),
      enabled => Enabled,
      description => Descr
     };

record_to_map(#action{hidden = true}) ->
    ignore;
record_to_map(#action{name = Name,
                      app = App,
                      for = Hook,
                      types = Types,
                      params_spec = Params,
                      title = Title,
                      description = Descr}) ->
    #{name => Name,
      app => App,
      for => Hook,
      types => Types,
      params => Params,
      title => Title,
      description => Descr
     };

record_to_map(#resource{id = Id,
                        type = Type,
                        config = Config,
                        description = Descr}) ->
    #{id => Id,
      type => Type,
      config => Config,
      description => Descr
     };

record_to_map(#resource_type{name = Name,
                             provider = Provider,
                             params_spec = Params,
                             title = Title,
                             description = Descr}) ->
    #{name => Name,
      provider => Provider,
      params => Params,
      title => Title,
      description => Descr
     }.

printable_actions(Actions) ->
    [#{id => Id, name => Name, params => Args,
       metrics => get_action_metrics(Id),
       fallbacks => printable_actions(Fallbacks)}
     || #action_instance{id = Id, name = Name, args = Args, fallbacks = Fallbacks} <- Actions].

parse_rule_params(Params) ->
    parse_rule_params(Params, #{description => <<"">>}).
parse_rule_params([], Rule) ->
    Rule;
parse_rule_params([{<<"id">>, Id} | Params], Rule) ->
    parse_rule_params(Params, Rule#{id => Id});
parse_rule_params([{<<"rawsql">>, RawSQL} | Params], Rule) ->
    parse_rule_params(Params, Rule#{rawsql => RawSQL});
parse_rule_params([{<<"enabled">>, Enabled} | Params], Rule) ->
    parse_rule_params(Params, Rule#{enabled => enabled(Enabled)});
parse_rule_params([{<<"on_action_failed">>, OnFailed} | Params], Rule) ->
    parse_rule_params(Params, Rule#{on_action_failed => on_failed(OnFailed)});
parse_rule_params([{<<"actions">>, Actions} | Params], Rule) ->
    parse_rule_params(Params, Rule#{actions => parse_actions(Actions)});
parse_rule_params([{<<"description">>, Descr} | Params], Rule) ->
    parse_rule_params(Params, Rule#{description => Descr});
parse_rule_params([_ | Params], Res) ->
    parse_rule_params(Params, Res).

on_failed(<<"continue">>) -> continue;
on_failed(<<"stop">>) -> stop;
on_failed(OnFailed) -> error({invalid_on_failed, OnFailed}).

enabled(Enabled) when is_boolean(Enabled) -> Enabled;
enabled(Enabled) -> error({invalid_enabled, Enabled}).

parse_actions(Actions) ->
    [parse_action(json_term_to_map(A)) || A <- Actions].

parse_action(Action) ->
    #{name => binary_to_existing_atom(maps:get(<<"name">>, Action), utf8),
      args => maps:get(<<"params">>, Action, #{}),
      fallbacks => parse_actions(maps:get(<<"fallbacks">>, Action, []))}.

parse_resource_params(Params) ->
    parse_resource_params(Params, #{config => #{}, description => <<"">>}).
parse_resource_params([], Res) ->
    Res;
parse_resource_params([{<<"id">>, Id} | Params], Res) ->
    parse_resource_params(Params, Res#{id => Id});
parse_resource_params([{<<"type">>, ResourceType} | Params], Res) ->
    try parse_resource_params(Params, Res#{type => binary_to_existing_atom(ResourceType, utf8)})
    catch error:badarg ->
        throw({resource_type_not_found, ResourceType})
    end;
parse_resource_params([{<<"config">>, Config} | Params], Res) ->
    parse_resource_params(Params, Res#{config => json_term_to_map(Config)});
parse_resource_params([{<<"description">>, Descr} | Params], Res) ->
    parse_resource_params(Params, Res#{description => Descr});
parse_resource_params([_ | Params], Res) ->
    parse_resource_params(Params, Res).

json_term_to_map(List) ->
    emqx_json:decode(emqx_json:encode(List), [return_maps]).

sort_by_title(action, Actions) ->
    sort_by(#action.title, Actions);
sort_by_title(resource_type, ResourceTypes) ->
    sort_by(#resource_type.title, ResourceTypes).

sort_by(Pos, TplList) ->
    lists:sort(
        fun(RecA, RecB) ->
            maps:get(en, element(Pos, RecA), 0)
            =< maps:get(en, element(Pos, RecB), 0)
        end, TplList).

get_rule_metrics(Id) ->
    [maps:put(node, Node, rpc:call(Node, emqx_rule_metrics, get_rule_metrics, [Id]))
     || Node <- [node()| nodes()]].

get_action_metrics(Id) ->
    [maps:put(node, Node, rpc:call(Node, emqx_rule_metrics, get_action_metrics, [Id]))
     || Node <- [node()| nodes()]].
