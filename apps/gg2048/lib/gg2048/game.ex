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


  @spec get_state(id()) :: ok_error(Game.t())
  @doc "For testing purposes. Might move it under the TEST macro"
  def get_state(id) do
    GenServer.call(via(id), :get_state)
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
    GenServer.call(via(id), {:move, player_id}, to)
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
  def handle_call(_call, _from, state = %Game{:phase => :finished}) do
    {:reply, {:error, :finished}, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call({:join, player_id}, _from, state) when
    state.phase == :init
    and not is_map_key(state.lobby, player_id)
    and map_size(state.lobby) < state.board.players.max
  do
    # Player joins new game
    Logger.info "Player #{player_id} joins the game lobby #{state.id}"
    {:reply, :ok, %Game{
      state | lobby: Map.put(
        state.lobby, player_id, %Gg2048.Player{id: player_id}
      )
    }}
  end

  def handle_call({:join, player_id}, _from, state) when
    state.phase == :started
    and is_map_key(state.lobby, player_id)
  do
    # Player reconnects to already started game
    lobby = state.lobby

    case lobby[player_id] do
      p = %Player{in_game: false} ->
        Logger.info "Player #{player_id} reconnected the game #{state.id}"

        {:reply, :ok, do_reconnect(state, p)}
      _ ->
        {:reply, {:error, :player_connected}, state}
    end
  end

  def handle_call(
    {:leave, player_id}, _from, state
  ) when state.phase == :init and is_map_key(state.lobby, player_id) do
    # Player leaves from not yet started game
    lobby = state.lobby

    Logger.info "Player #{player_id} leaves the game lobby #{state.id}"
    {:reply, :ok, %Game{state | lobby: Map.delete(lobby, player_id)}}
  end

  def handle_call(
    {:leave, player_id}, _from, state
  ) when state.phase == :started and is_map_key(state.lobby, player_id) do
    # Player for whatever reason stopped playing the game. It could have
    # been intentional decision or technical difficulties.
    # there is a chance the player would come back, meanwhile the game can
    # continue.
    lobby = state.lobby
    case lobby[player_id] do
      p = %Player{in_game: true} ->
        Logger.info "Player #{player_id} disconnected the game #{state.id}"
        {:reply, :ok, do_disconnect(state, p)}
      _ ->
        {:reply, {:error, :player_disconnected}, state}
    end
  end

  def handle_call(
    :start, _from, state
  ) when state.phase == :init
    and map_size(state.lobby) >= state.board.players.min
    and map_size(state.lobby) <= state.board.players.max
  do
    Logger.info "Starting the game #{state.id}"
    state = do_start(state)
    {:reply, :ok, %Game{state | phase: :started}}
  end

  def handle_call(
    {:move, player_id, to}, _from, state
  ) when state.phase == :started
    and hd(state.order) == player_id
  do
    {reply, state} = do_move(state, player_id, to)
    {:reply, reply, state}
  end

  def handle_call(:finish, _from, state) do
    Logger.info "Preparing to finish the game #{state.id}"
    # there are some calls might be in flight, let them finish
    GenServer.cast(self(), :finish)

    state = do_finish(state)
    {:reply, :ok, %Game{state | phase: :finished}}
  end

  def handle_call(call, _from, state) do
    {:reply, {:error, {:wrong_call, state, call}}, state}
  end


  @impl true
  def handle_cast(:finish, state = %Game{:id => id, :phase => :finished}) do
    Logger.info "Finishing game #{id}"

    {:stop, :normal, do_finish(state)}
  end


  ################
  ## private
  defp via(id) do
    {:via, Registry, {Gg2048.Game.Registry, id}}
  end


  defp do_start(state) do
    order =
      state.lobby
      |> Map.keys
      |> Enum.shuffle
    %Game{state | order: order}
  end


  def do_disconnect(state, p) do
    # after disconnect player no participates in the game
    lobby = %{state.lobby | p.id => %Player{p | in_game: false}}
    %Game{state | lobby: lobby, order: List.delete(state.order, p.id)}
  end

  def do_reconnect(state, p) do
    # after reconnect player becomes last to move
    lobby = %{state.lobby | p.id => %Player{p | in_game: true}}
    %Game{state | lobby: lobby, order: state.order ++ [p.id]}
  end


  def do_move(state, player_id, to) do
    Board.move(state.board, to)
  end

  defp do_finish(state) do
    # unregister the game from further interractions
    Registry.unregister(Gg2048.Game.Registry, state.id)

    # placeholder to send ladder stats
    state
  end
end
