defmodule Gg2048Web.Game do
  use Phoenix.LiveView

  alias Gg2048.{Game, Board}


  def mount(_params, _session, socket) do
    {:ok, socket}
  end


  def handle_event("new", value, socket) do
    {:noreply,  socket}
  end

  def handle_info(g = %Game{phase: :init}, socket) do
    # showing new games in lobby
    {:noreply, assign(socket, games: Map.put(socket.assigns.games, g.id, g))}
  end

  def render(assigns) do
    ~H"""
    """
  end
end
