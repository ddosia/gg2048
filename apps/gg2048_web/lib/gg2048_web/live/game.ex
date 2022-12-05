defmodule Gg2048Web.Game do
  use Phoenix.LiveView
  require Logger

  alias Gg2048.{Game, Board}


  def mount(params, session, socket) do
    ## terminate has to be reliable
    Process.flag(:trap_exit, true)

    %{"game_id" => game_id} = params
    Phoenix.PubSub.subscribe(Gg2048.PubSub, "game:#{game_id}")

    case Game.info(game_id) do
      {:ok, g} ->
        socket =
          socket
          |> assign(:is_connected, false)
          |> assign(:user_id, session["user_id"])
          |> assign(:game, g)

        if connected?(socket) do
          # It’s invoked once per cycle, but there are two cycles.
          # The first is the GET request which does a static render, and the next
          # is the websocket based request which does the live render.
          case Game.join(game_id, session["user_id"]) do
            :ok ->
              {:ok, assign(socket, :is_connected, true)}
            err ->
              {:ok, error(err, socket)}
          end
        else
          {:ok, socket}
        end
      err ->
        {:ok, error(err, socket)}
    end

  end


  def handle_event("start", value, socket) do
    socket =
      case Game.start(socket.assigns.game.id, socket.assigns.user_id) do
        :ok -> socket
        err -> error(err, socket)
      end
    {:noreply,  socket}
  end

  def handle_event(to, value, socket) when to in ["left", "right", "up", "down"] do
    case Game.move(
      socket.assigns.game.id, socket.assigns.user_id, String.to_atom(to)
    ) do
      :ok -> :ok
      {:error, :board_unchanged} -> :ok
      {:error, :player_wrong_order} -> :ok
    end

    {:noreply,  socket}
  end


  def handle_info(%Gg2048.Game{} = g, socket) do
    {:noreply, assign(socket, game: g)}
  end

  def handle_info(msg, socket) do
    Logger.warning "Unexpected message #{inspect self()}: #{inspect msg}"
    {:noreply, socket}
  end


  def terminate(_reason, socket) do
    Logger.debug "TERMINATE #{inspect self()}"

    if Map.get(socket.assigns, :is_connected, false) do
      :ok = Game.leave(socket.assigns.game.id, socket.assigns.user_id)
    end
  end


  def render(assigns) do
    ~H"""
    <section class="container border text-center">
      <div class="row">
        <div class="col-md-8">
          <%= if @game.phase == :init do %>
            <%= if Gg2048.Game.can_start?(@game.id, @user_id) do %>
              <button phx-click="start">START</button>
            <% end %>
          <% else %>
            <Gg2048Web.Game.Component.board game={@game} />
            <Gg2048Web.Game.Component.controls />
          <% end %>
        </div>
        <div class="col-md-4">
          <Gg2048Web.Game.Component.roster user_id={@user_id} game={@game} />
        </div>
      </div>
    </section>
    """
  end

  defp error({:error, err}, socket) do
    msg = "ERROR: #{err}"
    Logger.error msg
    socket |> put_flash(:error, msg) |> push_redirect(to: "/")
  end
end


defmodule Gg2048Web.Game.Component do
  use Phoenix.Component

  def roster(assigns) do
    ~H"""
      <table class="table">
        <thead>
          <th scope="col">ID</th>
          <th scope="col">Connected</th>
          <th scope="col">Score</th>
          <th scope="col">Turn</th>
        </thead>
        <tbody>
          <%= for {_id, p} <- @game.lobby do %>
            <.player game={@game} player={p} user_id={@user_id} />
          <% end %>
        </tbody>
      </table>
    """
  end

  def player(assigns) do
    # avoid empty list
    is_player_turn = hd(assigns.game.order ++ [:nil]) == assigns.player.id

    theme =
      if assigns.user_id == assigns.player.id and is_player_turn do
        "text-light bg-dark"
      else
        ""
      end


    ~H"""
      <tr class={theme}>
        <td>
          <%= if @player.id == @user_id do %>
            YOU
          <% else %>
            <%= @player.id %>
          <% end %>
        </td>
        <td>
          <%= @player.in_game %>
        </td>
        <td>
          <%= @player.score %>
        </td>
        <td>
          <%= is_player_turn %>
        </td>
      </tr>
    """
  end

  def board(assigns) do
    ~H"""
    <table class="table table-bordered">
      <%= for row <- Gg2048.Board.as_rect(@game.board) do %>
        <tr>
          <%= for val <- row do %>
            <td>
              <%= val %>
            </td>
          <% end %>
        </tr>
      <% end %>
    </table>
    """
  end

  def controls(assigns) do
    ~H"""
    <div class="container">
      <div class="row">
        <div class="col">
        </div>
        <div class="col">
          <button phx-click="up">UP</button>
        </div>
        <div class="col">
        </div>
      </div>
      <div class="row">
        <div class="col">
          <button phx-click="left">LEFT</button>
        </div>
        <div class="col">
        </div>
        <div class="col">
          <button phx-click="right">RIGHT</button>
        </div>
      </div>
      <div class="row">
        <div class="col">
        </div>
        <div class="col">
          <button phx-click="down">DOWN</button>
        </div>
        <div class="col">
        </div>
      </div>
    </div>
    """
  end
end
