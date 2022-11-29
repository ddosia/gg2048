defmodule GameTest do
  require Logger

  alias Gg2048.Game.{Sup, Board}

  use ExUnit.Case

  setup_all do
    {:ok, _} = Application.ensure_all_started(:gg2048)
  end

  setup do
    :ok

    on_exit fn ->
      for id <- Sup.children(), do: Board.finish(id)
    end
  end

  # Creates few new games, checks they could be successfully shut down.
  # Checks no dangling processes left.
  test "new > finish" do
    ids = for _ <- 1..10, do: Board.new()
    assert length(Sup.children()) == length(ids)

    for id <- ids, do: Board.finish(id)
    assert length(Sup.children()) == 0
  end


  test "board" do
    id = Board.new()
    assert is_map(Board.board(id))
  end
end
