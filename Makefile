.PHONY: all deps start dialyzer

start:
	iex -S mix phx.server

all: deps
	mix local.rebar --force

deps:
	mix do deps.get, deps.compile

dialyzer:
	mix dialyzer --format github

test:
	mix test
