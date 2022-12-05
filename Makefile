.PHONY: all deps start

start:
	iex -S mix phx.server

all: deps
	mix local.rebar --force

deps:
	mix do deps.get, deps.compile

dialyzer:
	mix dialyzer

test:
	mix test
