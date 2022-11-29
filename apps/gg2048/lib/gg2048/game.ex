defmodule Gg2048.Player do
  @type id :: String.t()

  @enforce_keys [:id]
  defstruct [:id, in_game: true]
  @type t :: %__MODULE__{
    id: id(),
    in_game: boolean()
  }
end


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
  @type ok_error() :: :ok | {:ok, any()} | {:error, any()}
  @type ok_error(ok) :: :ok | {:ok, ok} | {:error, any()}
  @type id :: Ecto.UUID.id

  @timeout 5 * 60
  @enforce_keys [:id, :board]
  defstruct [:id, :board, phase: :init, timeout: @timeout, lobby: %{}]
  @type t :: %__MODULE__{
    id: id(),
    board: Board.t(),
    phase: :init | :started | :finished,
    timeout: non_neg_integer(),
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
  def new(board \\ Board.default()) do
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


  @spec get_board(id()) :: ok_error(Board.t())
  def get_board(id) do
    GenServer.call(via(id), :get_board)
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

  def handle_call(:get_board, _from, state) do
    {:reply, {:ok, state.board}, state}
  end

  def handle_call({:join, player_id}, _from, state) when
    state.phase == :init
    and not is_map_key(state.lobby, player_id)
    and map_size(state.lobby) < state.board.players.max
  do
    # Player tries to join new game
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
    # Player tries to reconnect to already started game
    lobby = state.lobby

    case lobby[player_id] do
      p = %Player{in_game: false} ->
        Logger.info "Player #{player_id} reconnected the game #{state.id}"
        lobby = %{lobby | player_id => %Player{p | in_game: true}}

        {:reply, :ok, %Game{state | lobby: lobby}}
      _ ->
        {:reply, {:error, :player_connected}, state}
    end
  end

  def handle_call(
    {:leave, player_id}, _from, state
  ) when state.phase == :init and is_map_key(state.lobby, player_id) do
    lobby = state.lobby

    Logger.info "Player #{player_id} leaves the game lobby #{state.id}"
    {:reply, :ok, %Game{state | lobby: Map.delete(lobby, player_id)}}
  end

  def handle_call(
    {:leave, player_id}, _from, state
  ) when state.phase == :started and is_map_key(state.lobby, player_id) do
    # gamer for whatever reason stopped playing the game. It could have
    # been intentional decision or technical difficulties.
    # there is a chance the player would come back, meanwhile the game can
    # continue.
    lobby = state.lobby

    case lobby[player_id] do
      p = %Player{in_game: true} ->
        Logger.info "Player #{player_id} disconnected the game #{state.id}"
        lobby = %{lobby | player_id => %Player{p | in_game: false}}

        {:reply, :ok, %Game{state | lobby: lobby}}
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

  def handle_call(:finish, _from, state = %Game{:id => id}) do
    Logger.info "Preparing to finish the game #{id}"
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
    # placeholder to send ladder stats
    state
  end


  defp do_finish(state) do
    # unregister the game from further interractions
    Registry.unregister(Gg2048.Game.Registry, state.id)

    # placeholder to send ladder stats
    state
  end
end


defmodule Gg2048.Board do
  # map = Tuple.duplicate(Tuple.duplicate(0, x), y)
  @type minmax() :: %{
    min: non_neg_integer(),
    max: non_neg_integer()
  }

  defstruct [:map, size: %{min: 6, max: 6}, players: %{min: 1, max: 2}]
  @type t :: %__MODULE__{
    map: tuple(),
    size: minmax(),
    players: minmax()
  }

  def default() do
    %Gg2048.Board{}
  end
end
