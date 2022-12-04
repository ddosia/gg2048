defmodule Gg2048Web.GameController do
  alias Gg2048.{Game}

  use Gg2048Web, :controller

  def index(conn, _params) do
    game_ids = Gg2048.Game.Sup.children
    render(conn, "index.html", game_ids: game_ids)
  end

  def new(conn, _params) do
    game_id = Game.new()
    conn
    |> redirect(to: "/games/#{game_id}")
    |> halt()
    #render(conn, "new.html")
  end

  def show(conn, %{"id" => game_id}) do
    case Game.info(game_id) do
      {:ok, g} ->
        render(conn, "game.html", game: g)
      {:error, :game_not_found} ->
        conn |>
        put_flash(:error, "Game #{game_id} not found!")
        |> redirect(to: "/")
        |> halt()
    end
  end
end
