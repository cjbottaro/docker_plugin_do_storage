defmodule DoStorage.Interface.Http do
  @callback get!(binary, [{binary, binary}], Keyword.t) :: map
  @callback post!(binary, binary, [{binary, binary}]) :: map
end
