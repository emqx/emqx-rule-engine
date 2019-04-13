PROJECT = emqx_rule_engine
PROJECT_DESCRIPTION = EMQ X Rule Engine
PROJECT_VERSION = 0.2

NO_AUTOPATCH = cuttlefish

CUR_BRANCH := $(shell git branch | grep -e "^*" | cut -d' ' -f 2)
BRANCH := $(if $(filter $(CUR_BRANCH), master develop), $(CUR_BRANCH), develop)

DEPS = sqlparse minirest getopt
dep_getopt = git https://github.com/emqx/getopt v1.0.2
dep_sqlparse = git-emqx https://github.com/emqx/sqlparse 4.6.2
dep_minirest = git-emqx https://github.com/emqx/minirest v0.2.2

BUILD_DEPS = emqx cuttlefish
dep_emqx = git-emqx https://github.com/emqx/emqx $(BRANCH)
dep_cuttlefish = git-emqx https://github.com/emqx/cuttlefish v2.2.1

TEST_DEPS = emqx_ct_helpers
dep_emqx_ct_helpers = git-emqx https://github.com/emqx/emqx-ct-helpers develop

ERLC_OPTS += +debug_info
ERLC_OPTS += +warnings_as_errors +warn_export_all +warn_unused_import

EUNIT_OPTS = verbose

CT_SUITES = emqx_rule_engine emqx_rule_funcs emqx_rule_maps emqx_rule_sqlparser
COVER = true

$(shell [ -f erlang.mk ] || curl -s -o erlang.mk https://raw.githubusercontent.com/emqx/erlmk/master/erlang.mk)
include erlang.mk

CUTTLEFISH_SCRIPT = _build/default/lib/cuttlefish/cuttlefish

app.config: $(CUTTLEFISH_SCRIPT) etc/emqx_rule_engine.conf
	$(verbose) $(CUTTLEFISH_SCRIPT) -l info -e etc/ -c etc/emqx_rule_engine.conf -i priv/emqx_rule_engine.schema -d data

$(CUTTLEFISH_SCRIPT): rebar-deps
	@if [ ! -f cuttlefish ]; then make -C _build/default/lib/cuttlefish; fi

distclean::
	@rm -rf _build cover deps logs log data
	@rm -f rebar.lock compile_commands.json cuttlefish

rebar-deps:
	rebar3 get-deps

rebar-clean:
	@rebar3 clean

rebar-compile: rebar-deps
	rebar3 compile

rebar-ct: app.config
	rebar3 ct

rebar-eunit: $(CUTTLEFISH_SCRIPT)
	@rebar3 eunit

rebar-xref:
	@rebar3 xref
