defmodule DoStorage.Plug.Log do
  require Logger

  def init(options), do: options

  def call(conn, _options) do
    op = String.replace(conn.request_path, "/", "")
    params = Poison.encode!(conn.params)
    Logger.info("#{op} #{params}")
    conn
  end
end
