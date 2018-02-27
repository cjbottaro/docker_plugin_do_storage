defmodule DoStorage.Interface.System do
  @callback cmd(binary, [binary]) :: {binary, integer}
end
