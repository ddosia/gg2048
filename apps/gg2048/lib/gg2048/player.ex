defmodule Gg2048.Player do
  @type id :: String.t()

  @enforce_keys [:id]
  defstruct [:id, in_game: true]
  @type t :: %__MODULE__{
    id: id(),
    in_game: boolean()
  }
end
