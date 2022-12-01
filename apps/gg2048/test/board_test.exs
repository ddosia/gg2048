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

    assert Board.move(b, :right) == %Board{b | map: {
      0,0,0,0,0,0,
      0,0,0,0,0,2,
      0,0,0,0,8,2,
      0,0,0,0,0,4,
      0,0,0,0,0,4,
      0,0,0,0,8,4,
    }}
    assert Board.move(b, :left) == %Board{b | map: {
      0,0,0,0,0,0,
      2,0,0,0,0,0,
      8,2,0,0,0,0,
      4,0,0,0,0,0,
      4,0,0,0,0,0,
      8,4,0,0,0,0,
    }}
    assert Board.move(b, :up) == %Board{b | map: {
      4,8,0,4,4,4,
      0,0,0,4,2,2,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
    }}
    assert Board.move(b, :down) == %Board{b | map: {
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,0,0,0,
      0,0,0,4,2,2,
      4,8,0,4,4,4,
    }}
  end
end
