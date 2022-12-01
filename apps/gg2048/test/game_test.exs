defmodule GameTest do
  require Logger
  import TestHelper

  alias Gg2048.{Player, Game, Board}
  alias Gg2048.Game.{Sup}

  use ExUnit.Case

  setup do
    # most of the tests need a game and few players. These are predefined
    # actors and a game.

    game_id = Game.new(%Board{players: %{min: 1, max: 3}})

    state = [
      game_id: game_id,
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
    game_id = context[:game_id]
    assert Game.join(game_id, context[:alice].id) == :ok
    assert wrong_call(
      Game.join(game_id, context[:alice].id)
    )== {:join, context[:alice].id}
  end

  test "join two", context do
    game_id = context[:game_id]
    assert Game.join(game_id, context[:alice].id) == :ok
    assert Game.join(game_id, context[:bob].id) == :ok
  end

  # default game has three maximum players
  test "join full lobby", context do
    game_id = context[:game_id]
    assert Game.join(game_id, context[:alice].id) == :ok
    assert Game.join(game_id, context[:bob].id) == :ok
    assert Game.join(game_id, context[:carol].id) == :ok
    assert wrong_call(
      Game.join(game_id, context[:dave].id)
    ) == {:join, context[:dave].id}
  end

  test "join full -> leave join", context do
    game_id = context[:game_id]
    assert Game.join(game_id, context[:alice].id) == :ok
    assert Game.join(game_id, context[:bob].id) == :ok
    assert Game.join(game_id, context[:carol].id) == :ok
    assert wrong_call(
      Game.join(game_id, context[:dave].id)
    ) == {:join, context[:dave].id}

    assert Game.leave(game_id, context[:alice].id) == :ok
    assert Game.join(game_id, context[:dave].id) == :ok

  end

  test "leave without joining", context do
    game_id = context[:game_id]
    assert wrong_call(
      Game.leave(game_id, context[:alice].id)
    ) == {:leave, context[:alice].id}
  end

  test "start", context do
    game_id = context[:game_id]
    # not enough players
    assert wrong_call(Game.start(game_id)) == :start

    :ok = Game.join(game_id, context[:alice].id)
    assert Game.start(game_id) == :ok
  end

  test "disconnect from started", context do
    game_id = context[:game_id]
    :ok = Game.join(game_id, context[:alice].id)
    :ok = Game.start(game_id)

    assert Game.leave(game_id, context[:alice].id) == :ok
    assert Game.leave(game_id, context[:alice].id) == {:error, :player_disconnected}
    assert Game.join(game_id, context[:alice].id) == :ok
    assert Game.join(game_id, context[:alice].id) == {:error, :player_connected}
  end


  test "basic order", context do
    game_id = context[:game_id]
    player_ids = [
      context[:alice].id, context[:bob].id, context[:carol].id
    ] |> Enum.sort

    for p_id <- player_ids do
      :ok = Game.join(game_id, p_id)
    end
    :ok = Game.start(game_id)

    game = get_state(game_id)
    assert game.order |> Enum.sort == player_ids
  end

  test "disconnect/reconnect order", context do
    game_id = context[:game_id]
    player_ids = [
      context[:alice].id, context[:bob].id, context[:carol].id
    ] |> Enum.sort

    for p_id <- player_ids do
      :ok = Game.join(game_id, p_id)
    end
    :ok = Game.start(game_id)
    :ok = Game.leave(game_id, context[:alice].id)

    game = get_state(game_id)
    assert game.order |> Enum.sort == (player_ids -- [context[:alice].id])

    :ok = Game.join(game_id, context[:alice].id)

    game = get_state(game_id)
    assert List.last(game.order) == context[:alice].id
  end


  test "move order", context do
    game_id = context[:game_id]
    player_ids = [
      context[:alice].id, context[:bob].id, context[:carol].id
    ] |> Enum.sort

    for p_id <- player_ids do
      :ok = Game.join(game_id, p_id)
    end
    :ok = Game.start(game_id)

    game = get_state(game_id)

    replace_map(game_id)

    [p_id1, p_id2, p_id3] = game.order

    assert Game.move(game_id, p_id3, :up) == {:error, :player_wrong_order}
    assert Game.move(game_id, p_id2, :up) == {:error, :player_wrong_order}

    assert Game.move(game_id, p_id1, :up) == :ok
    assert Game.move(game_id, p_id2, :down) == :ok
    assert Game.move(game_id, p_id3, :up) == :ok

  end

  test "start adds random 2", context do
    game_id = context[:game_id]
    :ok = Game.join(game_id, context[:alice].id)

    # before game start, the map is empty
    assert [] = map_vals(game_id)

    # after game start 1 random value is placed
    :ok = Game.start(game_id)
    assert [{_, 2}] = map_vals(game_id)
  end


  test "move adds random 2", context do
    game_id = context[:game_id]
    :ok = Game.join(game_id, context[:alice].id)

    :ok = Game.start(game_id)

    replace_map(game_id)
    :ok = Game.move(game_id, context[:alice].id, :up)
    # 0 and 5 are the top corners
    assert [2] = for {pos, val} <- map_vals(game_id), pos != 0, pos != 5, do: val

    replace_map(game_id)
    :ok = Game.move(game_id, context[:alice].id, :down)
    # 30 and 35 are the bottom corners
    assert [2] = for {pos, val} <- map_vals(game_id), pos != 30, pos != 35, do: val
  end

  test "move scores", context do
    game_id = context[:game_id]
    :ok = Game.join(game_id, context[:alice].id)
    :ok = Game.join(game_id, context[:bob].id)

    :ok = Game.start(game_id)

    game = get_state(game_id)
    [p_id1, p_id2] = game.order

    replace_map(game_id)
    :ok = Game.move(game_id, p_id1, :up) # score: 64 * 2 + 32 * 2

    replace_map(game_id)
    :ok = Game.move(game_id, p_id2, :right) # score: 0

    replace_map(game_id)
    :ok = Game.move(game_id, p_id1, :down) # prev score doubles

    assert %Game{lobby: %{
      ^p_id1 => %Player{
        score: 384
      },
      ^p_id2 => %Player{
        score: 0
      },
    }} = get_state(game_id)
  end


  defp replace_map(game_id) do
    # After game start random values put into the map.
    # This complicates testing, so the map is replaced to a predefined one

    g = get_state(game_id)
    put_state(
      game_id,
      %Game{g | board: %Board{
        g.board | map: {
          64,0,0,0,0,32,
          0,0,0,0,0,0,
          0,0,0,0,0,0,
          0,0,0,0,0,0,
          0,0,0,0,0,0,
          64,0,0,0,0,32,
        }
      }}
    )
  end

  defp map_vals(game_id) do
    %Game{board: %Board{map: map}} = get_state(game_id)

    for pos <- 0..(tuple_size(map) - 1), elem(map, pos) != 0 do
      {pos, elem(map, pos)}
    end
  end
end
