PROJECT = emqx_rule_engine
PROJECT_DESCRIPTION = EMQ X Rule Engine
PROJECT_VERSION = 0.1.0

NO_AUTOPATCH = cuttlefish

BUILD_DEPS = emqx cuttlefish
dep_emqx = git-emqx https://github.com/emqx/emqx develop
dep_cuttlefish = git-emqx https://github.com/emqx/cuttlefish v2.2.1

ERLC_OPTS += +debug_info
ERLC_OPTS += +warnings_as_errors +warn_export_all +warn_unused_import

EUNIT_OPTS = verbose

CT_SUITES = emqx_rule_engine
COVER = true

$(shell [ -f erlang.mk ] || curl -s -o erlang.mk https://raw.githubusercontent.com/emqx/erlmk/master/erlang.mk)

include erlang.mk

app:: rebar.config

app.config::
	./deps/cuttlefish/cuttlefish -l info -e etc/ -c etc/emqx_rule_engine.conf -i priv/emqx_rule_engine.schema -d data

