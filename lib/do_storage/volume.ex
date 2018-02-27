defmodule DoStorage.Volume do
  defstruct [:name, :mountpoint, :options]

  def get(name) do
    case :ets.lookup(DoStorage, name) do
      [] -> {:error, "Volume (internal) #{name} does not exist"}
      [{_, volume}] -> {:ok, volume}
    end
  end

  def put(%__MODULE__{} = volume) do
    :ets.insert(DoStorage, {volume.name, volume})
    {:ok, volume}
  end

end
