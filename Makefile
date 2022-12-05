.PHONY: all deps start dialyzer rebar

start:
	iex -S mix phx.server

all: deps

deps: rebar
	mix do deps.get, deps.compile

rebar:
	mix local.rebar --force

dialyzer:
	mix dialyzer --format github

test:
	mix test
