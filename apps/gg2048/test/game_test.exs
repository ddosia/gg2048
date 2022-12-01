defmodule GameTest do
  require Logger
  import TestHelper

  alias Gg2048.{Player, Game, Board}
  alias Gg2048.Game.{Sup}

  use ExUnit.Case

  setup do
    # most of the tests need a game and few players. These are predefined
    # actors and a game.

    state = [
      game_id: Game.new(%Board{players: %{min: 1, max: 3}}),
      alice: %Player{id: "alice"},
      bob: %Player{id: "bob"},
      carol: %Player{id: "carol"},
      dave: %Player{id: "dave"},
      eve: %Player{id: "eve"},
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

  # default game has three maximum players
  test "join full lobby", context do
    assert Game.join(context[:game_id], context[:alice].id) == :ok
    assert Game.join(context[:game_id], context[:bob].id) == :ok
    assert Game.join(context[:game_id], context[:carol].id) == :ok
    assert wrong_call(
      Game.join(context[:game_id], context[:dave].id)
    ) == {:join, context[:dave].id}
  end

  test "join full -> leave join", context do
    assert Game.join(context[:game_id], context[:alice].id) == :ok
    assert Game.join(context[:game_id], context[:bob].id) == :ok
    assert Game.join(context[:game_id], context[:carol].id) == :ok
    assert wrong_call(
      Game.join(context[:game_id], context[:dave].id)
    ) == {:join, context[:dave].id}

    assert Game.leave(context[:game_id], context[:alice].id) == :ok
    assert Game.join(context[:game_id], context[:dave].id) == :ok

  end

  test "leave without joining", context do
    assert wrong_call(
      Game.leave(context[:game_id], context[:alice].id)
    ) == {:leave, context[:alice].id}
  end

  test "start", context do
    # not enough players
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


  test "basic order", context do
    player_ids = [
      context[:alice].id, context[:bob].id, context[:carol].id
    ] |> Enum.sort

    for p_id <- player_ids do
      assert Game.join(context[:game_id], p_id) == :ok
    end
    assert Game.start(context[:game_id]) == :ok

    {:ok, game} = Game.get_state(context[:game_id])
    assert game.order |> Enum.sort == player_ids
  end

  test "disconnect/reconnect order", context do
    player_ids = [
      context[:alice].id, context[:bob].id, context[:carol].id
    ] |> Enum.sort

    for p_id <- player_ids do
      assert Game.join(context[:game_id], p_id) == :ok
    end
    assert Game.start(context[:game_id]) == :ok

    assert Game.leave(context[:game_id], context[:alice].id) == :ok

    {:ok, game} = Game.get_state(context[:game_id])
    assert game.order |> Enum.sort == (player_ids -- [context[:alice].id])

    assert Game.join(context[:game_id], context[:alice].id) == :ok
    {:ok, game} = Game.get_state(context[:game_id])
    assert List.last(game.order) == context[:alice].id
  end
end
