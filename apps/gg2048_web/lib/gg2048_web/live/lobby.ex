defmodule Gg2048Web.Lobby do
  use Gg2048Web, :live_view

  alias Gg2048.{Game, Board}

  def mount(_params, session, socket) do
    Phoenix.PubSub.subscribe(Gg2048.PubSub, "lobby")

    games =
      for game_id <- Gg2048.Game.Sup.children,
      {:ok, g = %Gg2048.Game{phase: :init}} <- [Game.info(game_id)],
      into: %{},
      do: {g.id, g}

    socket =
      socket
      |> assign(:user_id, session["user_id"])
      |> assign(:games, games)

    {:ok, socket}
  end


  def handle_event("new", value, socket) do
    ## primitive validation

    %{
      "map_size" => map_size,
      "players_max" => players_max,
    } = value
    {rows, cols} =
      case map_size do
        "4x4" -> {4,4}
        "6x6" -> {6,6}
        "8x8" -> {8,8}
        "10x10" -> {10,10}
        "12x12" -> {12,12}
      end

    players_max = String.to_integer(players_max)
    true = players_max in 1..4

    game_id = Game.new(%Board{
      size: %{rows: rows, cols: cols},
      players: %{min: 1, max: players_max},
    })

    {:noreply,  push_redirect(socket, to: "/games/#{game_id}")}
  end


  def handle_info(g = %Game{phase: :init}, socket) do
    # showing new games in lobby
    {:noreply, assign(socket, games: Map.put(socket.assigns.games, g.id, g))}
  end
  def handle_info(g = %Game{phase: _}, socket) do
    # removing started and finished games from lobby
    {:noreply, assign(socket, games: Map.delete(socket.assigns.games, g.id))}
  end

  def render(assigns) do
    ~H"""
    <section class="container text-center">
      <div class="row">
        <div class="col-md-4">
          <form phx-submit="new">
            <div class="row">
              <label class="col-md-2">Size:</label>
              <div class="col-md-10">
                <select name="map_size" class="form-select">
                  <option value="4x4">4x4</option>
                  <option value="6x6">6x6</option>
                  <option value="8x8">8x8</option>
                  <option value="10x10">10x10</option>
                  <option value="12x12">12x12</option>
                </select>
              </div>
            </div>
            <div class="row">
              <label class="col-md-2">Max players:</label>
              <div class="col-md-10">
                <select name="players_max" class="form-select">
                  <option value="1">1</option>
                  <option value="2">2</option>
                  <option value="3">3</option>
                  <option value="4">4</option>
                </select>
              </div>
            </div>
            <div class="row">
              <div class="col-md-12">
                <button class="container">NEW</button>
              </div>
            </div>
          </form>
        </div>
        <div class="col-md-8">
          <Gg2048Web.Lobby.Component.games_summary games={@games} />
        </div>
      </div>
    </section>
    """
  end
end


defmodule Gg2048Web.Lobby.Component do
  use Phoenix.Component

  def games_summary(assigns) do
    ~H"""
      <table class="table table-striped ">
        <thead>
          <th scope="col">Join</th>
          <th scope="col">Players</th>
          <th scope="col">Size</th>
          <th scope="col">Created</th>
        </thead>
        <tbody>
          <%= for {_id, g} <- @games do %>
            <.game_summary game={g} />
          <% end %>
        </tbody>
      </table>
    """
  end

  def game_summary(assigns) do
    ~H"""
      <tr>
        <td>
          <a href={"games/#{@game.id}"}><%= @game.id %></a>
        </td>
        <td>
          <%= map_size(@game.lobby) %>/<%= @game.board.players.max %>
        </td>
        <td>
          <%= @game.board.size.rows %>x<%= @game.board.size.cols %>
        </td>
        <td>
          <%= @game.created %>
        </td>
      </tr>
    """
  end
end
