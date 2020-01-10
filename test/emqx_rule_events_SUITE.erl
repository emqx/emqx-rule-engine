-module(emqx_rule_events_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").

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
