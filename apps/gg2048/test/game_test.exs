defmodule GameTest do
  require Logger
  import TestHelper

  alias Gg2048.{Player, Game}
  alias Gg2048.Game.{Sup}

  use ExUnit.Case

  setup_all do
    {:ok, _} = Application.ensure_all_started(:gg2048)
  end

  setup do
    # most of the tests need a game and few players. These are predefined
    # actors and a game.

    state = [
      game_id: Game.new(),
      alice: %Player{id: "alice"},
      bob: %Player{id: "bob"},
      carol: %Player{id: "carol"}
    ]

    on_exit fn ->
      Game.finish(state[:game_id])
    end

    {:ok, state}
  end

  # Creates few new games, checks they could be successfully shut down.
  # Checks no dangling processes left.
  test "new > finish" do
    ids = for _ <- 1..10, do: Game.new()
    assert_contains(Sup.children(), ids)

    for id <- ids, do: Game.finish(id)
    assert_contains(Sup.children(), [])
  end


  test "board", context do
    {:ok, board} = Game.get_board(context[:game_id])
    assert is_map(board)
  end


  test "join twice", context do
    assert Game.join(context[:game_id], context[:alice].id) == :ok
    assert wrong_call(
      Game.join(context[:game_id], context[:alice].id)
    )== {:join, context[:alice].id}
  end

  test "join two", context do
    assert Game.join(context[:game_id], context[:alice].id) == :ok
    assert Game.join(context[:game_id], context[:bob].id) == :ok
  end

  # default game has two maximum players
  test "join full lobby", context do
    assert Game.join(context[:game_id], context[:alice].id) == :ok
    assert Game.join(context[:game_id], context[:bob].id) == :ok
    assert wrong_call(
      Game.join(context[:game_id], context[:carol].id)
    ) == {:join, context[:carol].id}
  end

  test "join full -> leave join", context do
    assert Game.join(context[:game_id], context[:alice].id) == :ok
    assert Game.join(context[:game_id], context[:bob].id) == :ok
    assert wrong_call(
      Game.join(context[:game_id], context[:carol].id)
    ) == {:join, context[:carol].id}

    assert Game.leave(context[:game_id], context[:alice].id) == :ok
    assert Game.join(context[:game_id], context[:carol].id) == :ok

  end

  test "leave without joining", context do
    assert wrong_call(
      Game.leave(context[:game_id], context[:alice].id)
    ) == {:leave, context[:alice].id}
  end

  test "start", context do
    assert wrong_call(Game.start(context[:game_id])) == :start

    assert Game.join(context[:game_id], context[:alice].id) == :ok
    assert Game.start(context[:game_id]) == :ok
  end

  test "disconnect from started", context do
    assert Game.join(context[:game_id], context[:alice].id) == :ok
    assert Game.start(context[:game_id]) == :ok

    assert Game.leave(context[:game_id], context[:alice].id) == :ok
    assert Game.leave(context[:game_id], context[:alice].id) == {:error, :player_disconnected}
    assert Game.join(context[:game_id], context[:alice].id) == :ok
    assert Game.join(context[:game_id], context[:alice].id) == {:error, :player_connected}
  end
end
