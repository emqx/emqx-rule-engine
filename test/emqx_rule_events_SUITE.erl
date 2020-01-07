-module(emqx_topic_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").

-import(emqx_topic,
        [ wildcard/1
        , match/2
        , validate/1
        , triples/1
        , prepend/2
        , join/1
        , words/1
        , systop/1
        , feed_var/3
        , parse/1
        , parse/2
        ]).

-define(N, 100000).

all() -> emqx_ct:all(?MODULE).

t_mod_hook_fun(_) ->
    Funcs = emqx_rule_events:module_info(exports),
    [?assert(lists:keymember(emqx_rule_events:hook_fun(Event), 1, Funcs)) ||
     Event <- ['client.connected',
               'client.disconnected',
               'session.subscribed',
               'session.unsubscribed',
               'message.acked',
               'message.dropped',
               'message.delivered'
              ]].
