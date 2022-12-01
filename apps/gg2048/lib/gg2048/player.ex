defmodule Gg2048.Player do
  @type id :: String.t()

  @enforce_keys [:id]
  defstruct [:id, in_game: true, score: 0]
  @type t :: %__MODULE__{
    id: id(),
    in_game: boolean(),
    score: non_neg_integer()
  }
end
