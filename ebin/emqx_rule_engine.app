{application, emqx_rule_engine, [
	{description, "EMQ X Rule Engine"},
	{vsn, "0.0.1"},
	{modules, ['emqx_rule_engine','emqx_rule_engine_app','emqx_rule_engine_sup']},
	{registered, [emqx_rule_engine_sup]},
	{applications, [kernel,stdlib]},
	{mod, {emqx_rule_engine_app, []}}
]}.