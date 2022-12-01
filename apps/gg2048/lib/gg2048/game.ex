defmodule Gg2048.Game.Sup do
  use DynamicSupervisor

  def specs() do
    [
      {Registry, keys: :unique, name: Gg2048.Game.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: __MODULE__}
    ]
  end

  @doc "Returns the list of the supervisors children ids"
  def children() do
    for {id} <- Registry.select(Gg2048.Game.Registry, [
      {{:"$1", :_, :_}, [], [{{:"$1"}}]}
    ]) do
      id
    end
  end

  def id2pid!(id) do
    [{pid, _}] = Registry.lookup(Gg2048.Game.Registry, id)
    pid
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end


defmodule Gg2048.Game do
  @type ok_error() :: Gg2048.ok_error()
  @type ok_error(ok) :: Gg2048.ok_error(ok)
  @type id :: Ecto.UUID.id

  @timeout 5 * 60
  @enforce_keys [:id, :board]
  defstruct [
    :id, :board,
    phase: :init,
    timeout: @timeout,
    order: [],
    lobby: %{}
  ]
  @type t :: %__MODULE__{
    id: id(),
    board: Board.t(),
    phase: :init | :started | :finished,
    timeout: non_neg_integer(),
    order: [Player.id()],
    lobby: %{
      Player.id() => Player.t()
    }
  }

  require Logger
  use GenServer, restart: :transient, shutdown: @timeout
  alias Gg2048.Game.{Sup}
  alias Gg2048.{Game, Board, Player}

  ################
  ## API
  @spec new(Board.t()) :: id()
  def new(board \\ %Board{}) do
    board = Board.init(board)
    id = Ecto.UUID.generate()

    {:ok, _} = DynamicSupervisor.start_child(
      Sup, %{
        :id => id,
        :start => {__MODULE__, :start_link, [id, board]},
        :restart => :transient,
        :shutdown => @timeout
      }
    )
    id
  end


  @spec join(id(), Player.id()) :: ok_error()
  @doc "New player enters the game"
  def join(id, player_id) do
    GenServer.call(via(id), {:join, player_id})
  end


  @spec leave(id(), Player.id()) :: ok_error()
  @doc "Existing player leaves the game"
  def leave(id, player_id) do
    GenServer.call(via(id), {:leave, player_id})
  end


  @spec start(id()) :: ok_error()
  def start(id) do
    GenServer.call(via(id), :start)
  end


  @spec move(id(), Player.id(), Board.to()) :: ok_error(Board.t())
  def move(id, player_id, to) do
    GenServer.call(via(id), {:move, player_id, to})
  end


  @spec finish(id()) :: ok_error()
  def finish(id) do
    GenServer.call(via(id), :finish)
  end


  ################
  ## callbacks
  def start_link(id, board) do
    GenServer.start_link(__MODULE__, [id, board], [name: via(id)])
  end


  @impl true
  def init([id, board]) do
    Logger.info "initializing new game #{id}"
    {:ok, %Game{:id => id, :board => board}}
  end


  @impl true
  def handle_call(_call, _from, g = %Game{:phase => :finished}) do
    {:reply, {:error, :finished}, g}
  end


  def handle_call({:join, player_id}, _from, g) when
    g.phase == :init
    and not is_map_key(g.lobby, player_id)
    and map_size(g.lobby) < g.board.players.max
  do
    # Player joins new game
    Logger.info "Player #{player_id} joins the game lobby #{g.id}"
    {:reply, :ok, %Game{
      g | lobby: Map.put(
        g.lobby, player_id, %Gg2048.Player{id: player_id}
      )
    }}
  end

  def handle_call({:join, player_id}, _from, g) when
    g.phase == :started
    and is_map_key(g.lobby, player_id)
  do
    # Player reconnects to already started game
    lobby = g.lobby

    case lobby[player_id] do
      p = %Player{in_game: false} ->
        Logger.info "Player #{player_id} reconnected the game #{g.id}"

        {:reply, :ok, do_reconnect(g, p)}
      _ ->
        {:reply, {:error, :player_connected}, g}
    end
  end

  def handle_call(
    {:leave, player_id}, _from, g
  ) when g.phase == :init and is_map_key(g.lobby, player_id) do
    # Player leaves from not yet started game
    lobby = g.lobby

    Logger.info "Player #{player_id} leaves the game lobby #{g.id}"
    {:reply, :ok, %Game{g | lobby: Map.delete(lobby, player_id)}}
  end

  def handle_call(
    {:leave, player_id}, _from, g
  ) when g.phase == :started and is_map_key(g.lobby, player_id) do
    # Player for whatever reason stopped playing the game. It could have
    # been intentional decision or technical difficulties.
    # there is a chance the player would come back, meanwhile the game can
    # continue.
    lobby = g.lobby
    case lobby[player_id] do
      p = %Player{in_game: true} ->
        Logger.info "Player #{player_id} disconnected the game #{g.id}"
        {:reply, :ok, do_disconnect(g, p)}
      _ ->
        {:reply, {:error, :player_disconnected}, g}
    end
  end

  def handle_call(
    :start, _from, g
  ) when g.phase == :init
    and map_size(g.lobby) >= g.board.players.min
    and map_size(g.lobby) <= g.board.players.max
  do
    Logger.info "Starting the game #{g.id}"
    g = do_start(g)
    {:reply, :ok, %Game{g | phase: :started}}
  end

  def handle_call({:move, player_id, to}, _from, g) when g.phase == :started
  do
    {reply, g} = do_move(g, player_id, to)
    {:reply, reply, g}
  end

  def handle_call(:finish, _from, g) do
    Logger.info "Preparing to finish the game #{g.id}"
    # there are some calls might be in flight, let them finish
    GenServer.cast(self(), :finish)

    g = do_finish(g)
    {:reply, :ok, %Game{g | phase: :finished}}
  end

  def handle_call(call, _from, g) do
    {:reply, {:error, {:wrong_call, g, call}}, g}
  end


  @impl true
  def handle_cast(:finish, g = %Game{:id => id, :phase => :finished}) do
    Logger.info "Finishing game #{id}"

    {:stop, :normal, do_finish(g)}
  end


  ################
  ## private
  defp via(id) do
    {:via, Registry, {Gg2048.Game.Registry, id}}
  end


  defp do_start(g) do
    order =
      g.lobby
      |> Map.keys
      |> Enum.shuffle

    %Game{ g |
      order: order,
      board: Board.place_rnd!(g.board)
    }
  end


  def do_disconnect(g, p) do
    # after disconnect player no participates in the game
    lobby = %{g.lobby | p.id => %Player{p | in_game: false}}
    %Game{g | lobby: lobby, order: List.delete(g.order, p.id)}
  end

  def do_reconnect(g, p) do
    # after reconnect player becomes last to move
    lobby = %{g.lobby | p.id => %Player{p | in_game: true}}
    %Game{g | lobby: lobby, order: g.order ++ [p.id]}
  end


  def do_move(g, player_id, _to) when hd(g.order) != player_id do
    {{:error, :player_wrong_order}, g}
  end
  def do_move(g, player_id, to)  do
    {move_score, new_board} = Board.move(g.board, to)
    if new_board != g.board do
      # the board map has changed, therefor move succeeded and some free space
      # emerged
      {:ok, order_shift(%Game{g |
        lobby: Map.update!(
          g.lobby, player_id, fn p ->
            %Player{ p | score:  p.score + move_score}
          end
        ),
        board: Board.place_rnd!(new_board)
      })}
    else
      {{:error, :board_unchanged}, g}
    end
  end

  defp do_finish(g) do
    # unregister the game from further interactions
    Registry.unregister(Gg2048.Game.Registry, g.id)

    # placeholder to send ladder stats
    g
  end


  defp order_shift(g) do
    # TODO: highly inefficient adding to the tail every time, replace data
    # structr
    {h, tl} = List.pop_at(g.order, 0)
    %Game{g | order: tl ++ [h]}
  end
end
