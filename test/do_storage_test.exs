defmodule DoStorageTest do
  use ExUnit.Case
  doctest DoStorage

  test "greets the world" do
    assert DoStorage.hello() == :world
  end
end
