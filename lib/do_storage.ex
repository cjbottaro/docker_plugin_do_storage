defmodule DoStorage do
  use Plug.Router
  require Logger
  alias DoStorage.{Volume, Api, Metadata, Attacher, Mounter}

  plug DoStorage.Plug.Json
  plug DoStorage.Plug.Log
  plug :match
  plug :dispatch
  plug :respond

  post "/VolumeDriver.Capabilities" do
    resp = %{
      Capabilities: %{
        Scope: "global"
      }
    }
    assign(conn, :resp, resp)
  end

  post "/VolumeDriver.Create" do
    %{"Name" => name, "Opts" => opts} = conn.params

    response = case Api.volume_get(name) do
      {:error, reason} -> %{"Err" => reason}
      {:ok, _volume} ->
        Volume.put(%Volume{name: name, options: opts})
        %{"Err" => ""}
    end

    assign(conn, :resp, response)
  end

  post "/VolumeDriver.Remove" do
    %{"Name" => name} = conn.params

    resp = case Mounter.umount(name) do
      {:ok, _volume} ->
        :ets.delete(DoStorage, name)
        %{Err: ""}
      {:error, reason} ->
        %{Err: reason}
    end

    assign(conn, :resp, resp)
  end

  post "/VolumeDriver.Mount" do
    %{"Name" => name} = conn.params

    resp = with {:ok, _} <- Attacher.attach(name, Metadata.id),
      {:ok, volume} <- Mounter.mount(name)
    do
      %{Err: "", Mountpoint: volume.mountpoint}
    else
      {:error, reason} -> %{Err: reason}
    end

    assign(conn, :resp, resp)
  end

  post "/VolumeDriver.Unmount" do
    %{"Name" => name} = conn.params

    resp = case Mounter.umount(name) do
      {:ok, _volume} -> %{Err: ""}
      {:error, reason} -> %{Err: reason}
    end

    assign(conn, :resp, resp)
  end

  post "/VolumeDriver.Path" do
    %{"Name" => name} = conn.params

    resp = case Volume.get(name) do
      {:error, reason} -> %{Err: reason}
      {:ok, volume} -> %{
        Mountpoint: volume.mountpoint,
        Err: ""
      }
    end

    assign(conn, :resp, resp)
  end

  post "/VolumeDriver.Get" do
    name = conn.params["Name"]

    resp = case Volume.get(name) do
      {:error, reason} -> %{Err: reason}
      {:ok, volume} -> %{
        Volume: %{
          Name: volume.name,
          Mountpoint: volume.mountpoint,
          Status: %{}
        },
        Err: ""
      }
    end

    assign(conn, :resp, resp)
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

    assign(conn, :resp, resp)
  end

  defp respond(conn, _options) do
    op = String.replace(conn.request_path, "/", "")
    response = conn.assigns[:resp] |> Poison.encode!
    Logger.info("#{op} ->> #{response}")
    send_resp(conn, 200, response)
  end

end
