defmodule DoStorage.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @plugins_path "/run/docker/plugins"
  @socket_file "do_storage.sock"

  def start(_type, _args) do

    :ets.new(DoStorage, [:public, :named_table])

    socket_path = if File.dir?(@plugins_path) do
      "#{@plugins_path}/#{@socket_file}"
    else
      @socket_file
    end

    if File.exists?(socket_path), do: File.rm(socket_path)

    children = [
      {
        Plug.Adapters.Cowboy,
        scheme: :http,
        plug: DoStorage,
        options: [ip: {:local, socket_path}, port: 0]
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DoStorage.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
