defmodule Gg2048.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Gg2048.PubSub}
    ] ++ Gg2048.Game.Sup.specs()

    Supervisor.start_link(children, strategy: :one_for_one, name: Gg2048.Supervisor)
  end
end
