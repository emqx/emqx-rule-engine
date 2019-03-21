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
            path   => "/rules/:id",
            func   => show_rule,
            descr  => "Show a rule"
           }).

-rest_api(#{name   => delete_rule,
            method => 'DELETE',
            path   => "/rules/:id",
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

-rest_api(#{name   => show_resource,
            method => 'GET',
            path   => "/resources/:id",
            func   => show_resource,
            descr  => "Show a resource"
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
        , show_resource_type/2
        ]).

%%------------------------------------------------------------------------------
%% Rules API
%%------------------------------------------------------------------------------

create_rule(_Bindings, Params) ->
    case emqx_rule_engine:create_rule(Params) of
        {ok, Rule} ->
            emqx_mgmt:return({ok, record_to_map(Rule)});
        {error, action_not_found} ->
            emqx_mgmt:return({error, 500, "Action Not Found"})
    end.

list_rules(_Bindings, _Params) ->
    return_all(emqx_rule_registry:get_rules()).

show_rule(#{id := Id}, _Params) ->
    reply_with(fun emqx_rule_registry:get_rule/1, Id).

delete_rule(#{id := Id}, _Params) ->
    ok = emqx_rule_registry:remove_rule(Id),
    emqx_mgmt:return().

%%------------------------------------------------------------------------------
%% Actions API
%%------------------------------------------------------------------------------

list_actions(#{}, _Params) ->
    return_all(emqx_rule_registry:get_actions()).

show_action(#{name := Name}, _Params) ->
    reply_with(fun emqx_rule_registry:get_action/1, Name).

%%------------------------------------------------------------------------------
%% Resources API
%%------------------------------------------------------------------------------

create_resource(#{}, Params) ->
    case emqx_rule_engine:create_resource(Params) of
        {ok, Resource} ->
            emqx_mgmt:return({ok, record_to_map(Resource)});
        {error, resource_type_not_found} ->
            emqx_mgmt:return({error, 500, "Resource Type Not Found"})
    end.

list_resources(#{}, _Params) ->
    return_all(emqx_rule_registry:get_resources()).

show_resource(#{id := Id}, _Params) ->
    reply_with(fun emqx_rule_registry:find_resource/1, Id).

delete_resource(#{id := Id}, _Params) ->
    ok = emqx_rule_registry:remove_resource(Id),
    emqx_mgmt:return().

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
    emqx_mgmt:return({ok, Data}).

reply_with(Find, Key) ->
    case Find(Key) of
        {ok, R} ->
            emqx_mgmt:return({ok, record_to_map(R)});
        not_found ->
            emqx_mgmt:return({error, 404, "Not Found"})
    end.

record_to_map(#rule{id = Id,
                    name = Name,
                    rawsql = RawSQL,
                    actions = Actions,
                    enabled = Enabled,
                    description = Descr}) ->
    #{id => Id,
      name => Name,
      rawsql => RawSQL,
      actions => Actions,
      enabled => Enabled,
      description => Descr
     };

record_to_map(#action{name = Name,
                      app = App,
                      params = Params,
                      description = Descr}) ->
    #{name => Name,
      app => App,
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
                             description = Descr}) ->
    #{name => Name,
      provider => Provider,
      description => Descr
     }.

