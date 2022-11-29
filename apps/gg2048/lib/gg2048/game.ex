defmodule Gg2048.Game do
  defmodule Sup do
    use DynamicSupervisor

    def all() do
      [
        {Registry, keys: :unique, name: Gg2048.Game.Registry},
        {DynamicSupervisor, strategy: :one_for_one, name: __MODULE__}
      ]
    end

    @impl true
    def init(_args) do
      DynamicSupervisor.init(strategy: :one_for_one)
    end
  end


  defmodule Board do
    @timeout 5 * 60
    @default_opts %{
      size: {6, 6}
    }

    @enforce_keys [:id]
    defstruct [:id, status: :setup, timeout: @timeout, players: %{}]
    @type t :: %__MODULE__{
      id: Ecto.UUID.t(),
      status: :setup | :started | :finished,
      timeout: non_neg_integer(),
      players: map()
    }

    use GenServer, restart: :transient, shutdown: @timeout

    ################
    ## API
    def new(opts \\ @default_opts) do
      id = Ecto.UUID.generate()

      {:ok, _} = DynamicSupervisor.start_child(
        Sup, %{
          :id => id,
          :start => {__MODULE__, :start_link, [id, board(opts)]},
          :restart => :transient,
          :shutdown => @timeout
        }
      )
      id
    end

    def finish(id) do
      :ok = GenServer.call(via(id), :finish)
    end


    ################
    ## callbacks

    def start_link(id, board) do
      GenServer.start_link(__MODULE__, [id, board], [name: via(id)])
    end

    @impl true
    def init([id, board]) do
      {:ok, %Board{:id => id}}
    end

    @impl true
    def handle_call(:finish, _from, board) do
      {:stop, :normal, :ok, do_finish(board)}
    end

    @impl true
    def handle_cast(_, board) do
      {:noreply, board}
    end

    ################
    ## private
    defp via(id) do
      {:via, Registry, {Gg2048.Game.Registry, id}}
    end

    defp board(opts) do
      %{size: {x, y}} = opts
      map = Tuple.duplicate(Tuple.duplicate(0, x), y)

      %{map: map}
    end

    defp do_finish(board) do
      # placeholder to send ladder stats
      %Board{board | status: :finished}
    end
  end

end
