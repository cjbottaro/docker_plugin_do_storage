defmodule DoStorage.Interface.File do
  @callback dir?(binary) :: boolean
  @callback exists?(binary) :: boolean
  @callback mkdir(binary) :: :ok | {:error, binary}
  @callback ls(binary) :: {:ok, [binary]} | {:error, binary}
end
