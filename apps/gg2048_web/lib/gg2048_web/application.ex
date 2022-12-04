defmodule Gg2048Web.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Endpoint (http/https)
      Gg2048Web.Endpoint
      # Start a worker by calling: Gg2048Web.Worker.start_link(arg)
      # {Gg2048Web.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Gg2048Web.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Gg2048Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
