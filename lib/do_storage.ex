defmodule DoStorage do
  use Plug.Router
  require Logger
  alias DoStorage.{Volume, Api, Metadata}

  plug :match
  plug DoStorage.Plug.Json
  plug DoStorage.Plug.Log
  plug :dispatch

  post "/VolumeDriver.Capabilities" do
    resp = %{
      Capabilities: %{
        Scope: "global"
      }
    }
    send_json(conn, resp)
  end

  post "/VolumeDriver.Create" do
    %{"Name" => name, "Opts" => opts} = conn.params

    response = case Api.retrieve_volume(name) do
      %{"volumes" => []} ->
        %{"Err" => "DigitalOcean volume '#{name}' does not exist"}
      %{"region" => %{"available" => false}} ->
        %{"Err" => "DigitalOcean volume '#{name}' not available in #{Metadata.region}"}
      _ ->
        volume = %Volume{name: name, options: opts}
        :ets.insert(DoStorage, {name, volume})
        %{"Err" => ""}
    end

    send_json(conn, response)
  end

  post "/VolumeDriver.Remove" do
    %{"Name" => name} = conn.params

    :ets.delete(DoStorage, name)

    resp = %{
      Err: ""
    }

    send_json(conn, resp)
  end

  post "/VolumeDriver.Mount" do
    resp = %{
      Err: "",
      Mountpoint: "/mnt/volumes/a"
    }
    send_json(conn, resp)
  end

  post "/VolumeDriver.Unmount" do
    resp = %{
      Err: "",
    }
    send_json(conn, resp)
  end

  post "/VolumeDriver.Path" do
    resp = %{
      Err: "",
      Mountpoint: "/mnt/volumes/a"
    }
    send_json(conn, resp)
  end

  post "/VolumeDriver.Get" do
    name = conn.params["Name"]

    resp = case :ets.lookup(DoStorage, name) do
      [] -> %{Err: "#{name} does not exist"}
      [{_, volume}] -> %{
        Volume: %{
          Name: volume.name,
          Mountpoint: volume.mountpoint,
          Status: %{}
        },
        Err: ""
      }
    end

    send_json(conn, resp)
  end

  post "/VolumeDriver.List" do
    volumes = :ets.match(DoStorage, {:"_", :"$1"})
      |> List.flatten
      |> Enum.map(fn volume ->
        %{
          Name: volume.name,
          Mountpoint: volume.mountpoint
        }
      end)

    resp = %{
      Err: "",
      Volumes: volumes
    }

    send_json(conn, resp)
  end

  defp send_json(conn, jsonable) do
    send_resp(conn, 200, Poison.encode!(jsonable))
  end

end
