defmodule Gg2048.Board do
  @type ok_error() :: Gg2048.ok_error()
  @type ok_error(ok) :: Gg2048.ok_error(ok)
  @type to :: :up | :right | :down | :left

  defstruct [:map, size: %{rows: 6, cols: 6}, players: %{min: 1, max: 2}]
  @type t :: %__MODULE__{
    map: tuple(), # flat 2d map
    size: %{rows: pos_integer(), cols: pos_integer()},
    players: %{min: pos_integer(), max: pos_integer()},
  }

  alias Gg2048.{Board}

  def init(board) do
    map = Tuple.duplicate(0, board.size.rows * board.size.cols)
    %Board{board | map: map}
  end

  @spec move(t(), to()) :: ok_error(t())
  def move(board, to) when to == :up or to == :down do
    size = board.size.cols
    move_factor = size

    Enum.reduce(
      1..size, board, fn x, board_upd ->
        start_pos = x - 1
        end_pos = size * (board.size.rows - 1) + (x - 1)

        move_1(board_upd, to, move_factor, start_pos, end_pos)
      end
    )
  end
  def move(board, to) when to == :left or to == :right do
    size = board.size.rows
    move_factor = 1

    Enum.reduce(
      1..size, board, fn x, board_upd ->
        start_pos = (x - 1) * size
        end_pos = x * size - 1
        move_1(board_upd, to, move_factor, start_pos, end_pos)
      end
    )
  end


  ################
  ## private
  #
  # Places 2 at random 0-cell
  defp place_2(board) do
    pos = pos_0(board)
    %Board{board | map: put_elem(board.map, pos, 2)}
  end


  # Randomly selects one of the 0-cells
  defp pos_0(%Board{map: map}) do
    for pos <- 0..(tuple_size(map) - 1), elem(map, pos) == 0 do
      pos
    end |> Enum.shuffle |> hd
  end


  defp move_1(board, to, move_factor, start_pos, end_pos) do
    if to == :right or to == :down do
      do_move_1(
        board, -move_factor, end_pos - move_factor, end_pos, start_pos
      )
    else
      do_move_1(
        board, move_factor, start_pos + move_factor, start_pos, end_pos
      )
    end
  end

  @doc "Moves either column or row"
  defp do_move_1(
    board, move_factor, cur_pos, _bottom_pos, top_pos
  ) when cur_pos - move_factor == top_pos do
    board
  end
  defp do_move_1(board, move_factor, cur_pos, bottom_pos, top_pos) do
    map = board.map
    bottom_num = elem(map, bottom_pos)

    case elem(map, cur_pos) do
      0 ->
        do_move_1(
          board, move_factor, cur_pos + move_factor, bottom_pos, top_pos
        )
      _ when bottom_num == 0 ->
        # move to the bottom, since the bottom is 0
        swap_xy(board, bottom_pos, cur_pos)
        |> do_move_1(
          move_factor, cur_pos + move_factor, bottom_pos, top_pos
        )
      num when bottom_num == num ->
        # stack to the bottom, since bottom and current have same value
        stack_xy(board, cur_pos, bottom_pos)
        |> do_move_1(
          move_factor, cur_pos + move_factor, bottom_pos + move_factor, top_pos
        )
      num when bottom_num != num ->
        # move the current element on top of bottom
        swap_xy(board, cur_pos, bottom_pos + move_factor)
        |> do_move_1(
          move_factor, cur_pos + move_factor, bottom_pos + move_factor, top_pos
        )
    end
  end


  # Swaps two board.map values by given coordinates
  defp swap_xy(board, x, y) do
    map = board.map
    x_val = elem(map, x)
    y_val = elem(map, y)

    %Board{board | map: map |> put_elem(x, y_val) |> put_elem(y, x_val)}
  end


  # Stacks value to the second equal value, zeroes first
  defp stack_xy(board, x, y) do
    map = board.map
    val = elem(map, x)
    ^val = elem(map, y)

    %Board{board | map: map |> put_elem(x, 0) |> put_elem(y, val + val)}
  end
end
