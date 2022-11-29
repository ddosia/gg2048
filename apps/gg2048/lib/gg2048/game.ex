defmodule Gg2048.Game do
  @type ok_error(ok) :: :ok | {:ok, ok} | {:error, any()}

  defmodule Sup do
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


  defmodule Board do
    @type id :: Ecto.UUID.id
    @type board :: %{
      map: tuple()
    }

    @timeout 5 * 60
    @default_opts %{
      size: {6, 6}
    }

    @enforce_keys [:id, :board]
    defstruct [:id, :board, status: :setup, timeout: @timeout, players: %{}]
    @type t :: %__MODULE__{
      id: id(),
      board: board(),
      status: :setup | :started | :finished,
      timeout: non_neg_integer(),
      players: map()
    }

    use GenServer, restart: :transient, shutdown: @timeout
    require Logger

    ################
    ## API
    @spec new(%{}) :: id()
    def new(opts \\ @default_opts) do
      id = Ecto.UUID.generate()

      {:ok, _} = DynamicSupervisor.start_child(
        Sup, %{
          :id => id,
          :start => {__MODULE__, :start_link, [id, init_board(opts)]},
          :restart => :transient,
          :shutdown => @timeout
        }
      )
      id
    end

    @spec board(id()) :: Gg2048.Game.ok_error(board())
    def board(id) do
      GenServer.call(via(id), :board)
    end

    @spec board(id()) :: Gg2048.Game.ok_error()
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
      {:ok, %Board{:id => id, :board => board}}
    end


    @impl true
    def handle_call(:board, _from, state) do
      {:reply, state.board, state}
    end

    def handle_call(
      :finish, _from, state = %Board{:id => id}
    ) when state.status != :finished do
      Logger.info "Preparing to finish the game #{id}"
      # there are some calls might be in flight, let them finish
      GenServer.cast(self(), :finish)

      state = do_finish(state)
      {:reply, :ok, %Board{state | status: :finished}}
    end


    @impl true
    def handle_cast(:finish, state = %Board{:id => id, :status => :finished}) do
      Logger.info "Finishing game #{id}"

      {:stop, :normal, do_finish(state)}
    end

    ################
    ## private
    defp via(id) do
      {:via, Registry, {Gg2048.Game.Registry, id}}
    end

    defp init_board(opts) do
      %{size: {x, y}} = opts
      map = Tuple.duplicate(Tuple.duplicate(0, x), y)

      %{map: map}
    end

    defp do_finish(state) do
      # unregister the game from further interractions
      Registry.unregister(Gg2048.Game.Registry, state.id)

      # placeholder to send ladder stats
      state

    end
  end
end
