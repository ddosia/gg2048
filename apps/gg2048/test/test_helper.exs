ExUnit.start(capture_log: true)

defmodule TestHelper do
  use ExUnit.Case

  def wrong_call({:error, {:wrong_call, _, call}}) do
    # TODO: error handling is a bit primitive
    call
  end


  def assert_contains(big, small) when is_list(big) and is_list(small) do
    assert small -- big == []
  end
end
