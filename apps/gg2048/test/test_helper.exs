ExUnit.start(capture_log: true)

defmodule TestHelper do
  use ExUnit.Case
  alias Gg2048.Game.{Sup}

  def get_state(game_id) do
    :sys.get_state(Sup.id2pid!(game_id))
  end

  def put_state(game_id, g) do
    :sys.replace_state(
      Sup.id2pid!(game_id),
      fn _old_state -> g end
    )
  end

  def wrong_call({:error, {:wrong_call, _, call}}) do
    # TODO: error handling is a bit primitive
    call
  end


  def assert_contains(big, small) when is_list(big) and is_list(small) do
    assert small -- big == []
  end

  def assert_ok(res) do
    if is_tuple(res) do
      assert elem(res, 0) == :ok
    else
      assert res == :ok
    end
  end
end
