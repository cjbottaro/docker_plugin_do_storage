defmodule DoStorage.Plug.Json do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _options) do
    {:ok, body, conn} = read_body(conn)
    json = Poison.decode!(body)
    %{conn | params: json, body_params: json}
  end

end
