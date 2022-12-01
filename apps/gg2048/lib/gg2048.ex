defmodule Gg2048 do
  @type ok_error() :: :ok | {:ok, any()} | {:error, any()}
  @type ok_error(ok) :: :ok | {:ok, ok} | {:error, any()}
end
