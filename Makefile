
REBAR = rebar3 as test

all:
	$(REBAR) compile

eunit:
	$(REBAR) eunit -v

ct:
	$(REBAR) ct -v

xref:
	$(REBAR) xref

dialyzer:
	$(REBAR) dialyzer
