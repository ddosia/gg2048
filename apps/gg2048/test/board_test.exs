defmodule BoardTest do
  alias Gg2048.{Board}

  use ExUnit.Case

  test "new board" do
    b = %Board{size: %{rows: 6, cols: 7}}
    %Board{map: map} =  Board.init(b)
    assert tuple_size(map) == 6 * 7
  end

  test "move" do
    b = %Board{
      map: {
        0,0,0,0,0,0,
        0,0,0,0,0,2,
        0,8,0,0,2,0,
        0,0,0,2,0,2,
        0,0,0,2,2,0,
        4,0,0,4,2,2,
      },
      size: %{rows: 6, cols: 6}
    }

    assert {20, %Board{map: {
      0,0,0,0,0,0,
      0,0,0,0,0,2,
      0,0,0,0,8,2,
      0,0,0,0,0,4,
      0,0,0,0,0,4,
      0,0,0,0,8,4,
    }}} = Board.move(b, :right)

    assert {20, %Board{map: {
      0,0,0,0,0,0,
      2,0,0,0,0,0,
      8,2,0,0,0,0,
      4,0,0,0,0,0,
      4,0,0,0,0,0,
      8,4,0,0,0,0,
    }}} = Board.move(b, :left)

    assert {12, %Board{map: {
      4,8,0,4,4,4,
      0,0,0,4,2,2,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
    }}} = Board.move(b, :up)

    assert {12, %Board{map: {
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,4,2,2,
      4,8,0,4,4,4,
    }}} = Board.move(b, :down)

  end

  test "place random 2" do
    b = %Board{
      map: {
        0,2,4,
        8,0,6,
        6,4,0,
      },
      size: %{rows: 3, cols: 3}
    }

    b = b |> Board.place_rnd! |> Board.place_rnd! |> Board.place_rnd!

    assert b.map == {
      2,2,4,
      8,2,6,
      6,4,2,
    }
  end

  test "score" do
    b = %Board{
      map: {
        0,0,0,0,
        0,0,0,0,
        0,0,0,0,
        0,0,0,0,
      },
      size: %{rows: 4, cols: 4}
    }

    assert {0, _} = Board.move(b, :right)

    assert {0, _} = Board.move(%Board{b | map: {
      2,0,0,0,
      0,0,0,0,
      0,0,0,0,
      0,0,0,0,
    }}, :right)

    assert {48, _} = Board.move(%Board{b | map: {
      0,2,0,2,
      4,2,0,2,
      4,0,0,4,
      8,8,8,8,
    }}, :right)
  end
end
