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

-module(emqx_rule_engine_api).

-include("rule_engine.hrl").

-import(minirest,  [return/0, return/1]).

-rest_api(#{name   => create_rule,
            method => 'POST',
            path   => "/rules/",
            func   => create_rule,
            descr  => "Create a rule"
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

-rest_api(#{name   => list_actions_by_type,
            method => 'GET',
            path   => "/resource_types/:atom:type/actions",
            func   => list_actions_by_type,
            descr  => "List all actions of a resource type"
           }).

-export([ create_rule/2
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
        , delete_resource/2
        ]).

-export([ list_resource_types/2
        , list_resources_by_type/2
        , list_actions_by_type/2
        , show_resource_type/2
        ]).

-define(ERR_NO_ACTION(NAME), list_to_binary(io_lib:format("Action ~s Not Found", [(NAME)]))).
-define(ERR_NO_RESOURCE(RESID), list_to_binary(io_lib:format("Resource ~s Not Found", [(RESID)]))).
-define(ERR_NO_HOOK(HOOK), list_to_binary(io_lib:format("Hook ~s Not Found", [(HOOK)]))).
-define(ERR_NO_RESOURCE_TYPE(TYPE), list_to_binary(io_lib:format("Resource Type ~s Not Found", [(TYPE)]))).
-define(ERR_BADARGS(REASON),
        begin
            R0 = list_to_binary(io_lib:format("~0p", [REASON])),
            <<"Bad Arguments: ", R0/binary>>
        end).

%%------------------------------------------------------------------------------
%% Rules API
%%------------------------------------------------------------------------------

create_rule(_Bindings, Params) ->
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
        _Error:Reason ->
            return({error, 400, ?ERR_BADARGS(Reason)})
    end.

list_rules(_Bindings, _Params) ->
    return_all(emqx_rule_registry:get_rules()).

show_rule(#{id := Id}, _Params) ->
    reply_with(fun emqx_rule_registry:get_rule/1, Id).

delete_rule(#{id := Id}, _Params) ->
    ok = emqx_rule_registry:remove_rule(Id),
    return().

%%------------------------------------------------------------------------------
%% Actions API
%%------------------------------------------------------------------------------

list_actions(#{}, Params) ->
    case proplists:get_value(<<"for">>, Params) of
        undefined ->
            return_all(emqx_rule_registry:get_actions());
        Hook ->
            try binary_to_existing_atom(Hook, utf8) of
                Hook0 -> return_all(emqx_rule_registry:get_actions_for(Hook0))
            catch _:badarg -> return({error, 400, ?ERR_NO_HOOK(Hook)})
            end
    end.

show_action(#{name := Name}, _Params) ->
    reply_with(fun emqx_rule_registry:find_action/1, Name).

%%------------------------------------------------------------------------------
%% Resources API
%%------------------------------------------------------------------------------

create_resource(#{}, Params) ->
    try emqx_rule_engine:create_resource(parse_resource_params(Params)) of
        {ok, Resource} ->
            return({ok, record_to_map(Resource)});
        {error, {resource_type_not_found, Type}} ->
            return({error, 400, ?ERR_NO_RESOURCE_TYPE(Type)})
    catch
        throw:{resource_type_not_found, Type} ->
            return({error, 400, ?ERR_NO_RESOURCE_TYPE(Type)});
        _Error:Reason ->
            return({error, 400, ?ERR_BADARGS(Reason)})
    end.

list_resources(#{}, _Params) ->
    return_all(emqx_rule_registry:get_resources()).

list_resources_by_type(#{type := Type}, _Params) ->
    return_all(emqx_rule_registry:get_resources_by_type(Type)).

list_actions_by_type(#{type := Type}, _Params) ->
    return_all(emqx_rule_registry:get_actions_by_type(Type)).

show_resource(#{id := Id}, _Params) ->
    reply_with(fun emqx_rule_registry:find_resource/1, Id).

delete_resource(#{id := Id}, _Params) ->
    try
        ok = emqx_rule_registry:remove_resource(Id),
        return()
    catch
        _Error:{throw, Reason} ->
            return({error, 400, ?ERR_BADARGS(Reason)});
        _Error:Reason ->
            return({error, 400, ?ERR_BADARGS(Reason)})
    end.

%%------------------------------------------------------------------------------
%% Resource Types API
%%------------------------------------------------------------------------------

list_resource_types(#{}, _Params) ->
    return_all(emqx_rule_registry:get_resource_types()).

show_resource_type(#{name := Name}, _Params) ->
    reply_with(fun emqx_rule_registry:find_resource_type/1, Name).

%%------------------------------------------------------------------------------
%% Internal functions
%%------------------------------------------------------------------------------

return_all(Records) ->
    Data = lists:map(fun record_to_map/1, Records),
    return({ok, Data}).

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
                    enabled = Enabled,
                    description = Descr}) ->
    #{id => Id,
      for => Hook,
      rawsql => RawSQL,
      actions => [maps:remove(apply, Act) || Act <- Actions],
      enabled => Enabled,
      description => Descr
     };

record_to_map(#action{name = Name,
                      app = App,
                      for = Hook,
                      type = Type,
                      params = Params,
                      description = Descr}) ->
    #{name => Name,
      app => App,
      for => Hook,
      type => Type,
      params => Params,
      description => Descr
     };

record_to_map(#resource{id = Id,
                        type = Type,
                        config = Config,
                        attrs = Attrs,
                        description = Descr}) ->
    #{id => Id,
      type => Type,
      config => Config,
      attrs => Attrs,
      description => Descr
     };

record_to_map(#resource_type{name = Name,
                             provider = Provider,
                             params = Params,
                             description = Descr}) ->
    #{name => Name,
      provider => Provider,
      params => Params,
      description => Descr
     }.

parse_rule_params(Params) ->
    parse_rule_params(Params, #{description => <<"">>}).
parse_rule_params([], Rule) ->
    Rule;
parse_rule_params([{<<"for">>, Hook} | Params], Rule) ->
    parse_rule_params(Params, Rule#{for => ?RAISE(binary_to_existing_atom(Hook,utf8), {invalid_hook,Hook})});
parse_rule_params([{<<"rawsql">>, RawSQL} | Params], Rule) ->
    parse_rule_params(Params, Rule#{rawsql => RawSQL});
parse_rule_params([{<<"actions">>, Actions} | Params], Rule) ->
    parse_rule_params(Params, Rule#{actions => [parse_action(json_term_to_map(A)) || A <- Actions]});
parse_rule_params([{<<"description">>, Descr} | Params], Rule) ->
    parse_rule_params(Params, Rule#{description => Descr});
parse_rule_params([_ | Params], Res) ->
    parse_rule_params(Params, Res).

parse_action(Actions) ->
    case maps:find(<<"params">>, Actions) of
        error ->
            {binary_to_existing_atom(maps:get(<<"name">>, Actions), utf8), #{}};
        {ok, Params} ->
            {binary_to_existing_atom(maps:get(<<"name">>, Actions), utf8),
             Params}
    end.

parse_resource_params(Params) ->
    parse_resource_params(Params, #{config => #{}, description => <<"">>}).
parse_resource_params([], Res) ->
    Res;
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
    jsx:decode(jsx:encode(List), [return_maps]).