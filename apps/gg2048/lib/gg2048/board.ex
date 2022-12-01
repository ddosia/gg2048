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

  @spec move(t(), to()) :: ok_error({score:: non_neg_integer(), t()})
  def move(board, to) when to == :up or to == :down do
    size = board.size.cols
    move_factor = size

    Enum.reduce(
      1..size,
      {0, board},
      fn x, {score, board_upd} ->
        start_pos = x - 1
        end_pos = size * (board.size.rows - 1) + (x - 1)

        move_1({score, board_upd}, to, move_factor, start_pos, end_pos)
      end
    )
  end
  def move(board, to) when to == :left or to == :right do
    size = board.size.rows
    move_factor = 1

    Enum.reduce(
      1..size,
      {0, board},
      fn x, {score, board_upd} ->
        start_pos = (x - 1) * size
        end_pos = x * size - 1
        move_1({score, board_upd}, to, move_factor, start_pos, end_pos)
      end
    )
  end


  @spec place_rnd!(Board.t(), integer()) :: Board.t()
  @doc "Places a value at random 0-cell"
  def place_rnd!(board, val \\ 2) do
    %Board{board | map: put_elem(board.map, pos_0(board), val)}
  end


  @doc "Calculates a score: a difference between two states of the board"
  def score(board_prev, board_next) do
    List.zip([board_prev.map, board_next.map])
    |> Enum.reduce(
      0, fn {prev_val, next_val}, score -> score + (next_val - prev_val) end
    )
  end

  ################
  ## private
  #
  defp move_1({score, board}, to, move_factor, start_pos, end_pos) do
    if to == :right or to == :down do
      do_move_1(
        {score, board}, -move_factor, end_pos - move_factor, end_pos, start_pos
      )
    else
      do_move_1(
        {score, board}, move_factor, start_pos + move_factor, start_pos, end_pos
      )
    end
  end

  # Moves either a column or a row
  defp do_move_1(
    {score, board}, move_factor, cur_pos, _bottom_pos, top_pos
  ) when cur_pos - move_factor == top_pos do
    {score, board}
  end
  defp do_move_1({score, board}, move_factor, cur_pos, bottom_pos, top_pos) do
    map = board.map
    bottom_num = elem(map, bottom_pos)

    case elem(map, cur_pos) do
      0 ->
        do_move_1(
          {score, board}, move_factor, cur_pos + move_factor, bottom_pos, top_pos
        )
      _ when bottom_num == 0 ->
        # move to the bottom, since the bottom is 0
        do_move_1(
          {score, swap(board, bottom_pos, cur_pos)},
          move_factor, cur_pos + move_factor, bottom_pos, top_pos
        )
      num when bottom_num == num ->
        # stack to the bottom, since bottom and current have the same value
        do_move_1(
          {score + num * 2, stack(board, cur_pos, bottom_pos)},
          move_factor, cur_pos + move_factor, bottom_pos + move_factor, top_pos
        )
      num when bottom_num != num ->
        # move the current element above of bottom
        do_move_1(
          {score, swap(board, cur_pos, bottom_pos + move_factor)},
          move_factor, cur_pos + move_factor, bottom_pos + move_factor, top_pos
        )
    end
  end


  # Randomly selects one of the 0-cells
  defp pos_0(%Board{map: map}) do
    for pos <- 0..(tuple_size(map) - 1), elem(map, pos) == 0 do
      pos
    end |> Enum.shuffle |> hd
  end


  # Swaps two board.map values by given coordinates
  defp swap(board, x, y) do
    map = board.map
    x_val = elem(map, x)
    y_val = elem(map, y)

    %Board{board | map: map |> put_elem(x, y_val) |> put_elem(y, x_val)}
  end


  # Stacks value to the second equal value, zeroes first
  defp stack(board, x, y) do
    map = board.map
    val = elem(map, x)
    ^val = elem(map, y)

    %Board{board | map: map |> put_elem(x, 0) |> put_elem(y, val + val)}
  end
end
