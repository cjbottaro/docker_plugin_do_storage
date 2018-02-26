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

    response = case Api.volume_get(name) do
      {:error, reason} -> %{"Err" => reason}
      {:ok, volume} ->
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
    %{"Name" => name} = conn.params

    {:ok, volume} = Api.volume_get(name)
    attach(volume)
    mount(volume)

    resp = %{
      Err: "",
      Mountpoint: "/mnt/volumes/#{name}"
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
    %{"Name" => name} = conn.params

    resp = %{
      Err: "",
      Mountpoint: "/mnt/volumes/#{name}"
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

  def attach(volume, droplet_id \\ nil) do
    name = volume["name"]
    volume_id = volume["id"]
    droplet_id = droplet_id || Metadata.id
    droplet_ids = volume["droplet_ids"]

    cond do
      # Hey, we're already attached!
      Enum.member?(droplet_ids, droplet_id) -> :ok

      # Volume is attached to another droplet, detach and retry.
      length(droplet_ids) != 0 ->
        detach_droplet_id = List.first(droplet_ids)
        with {:ok, action} <- Api.volume_detach(detach_droplet_id, volume_id),
          {:ok, action} <- wait_for(action)
        do
          case action do
            %{"status" => "errored"} -> {:error, "Detaching volume #{name} from #{droplet_id} failed"}
            _ -> volume |> Map.put("droplet_ids", []) |> attach(droplet_id)
          end
        end

      # Not attached to anything, so we can attach.
      true ->
        with {:ok, action} <- Api.volume_attach(droplet_id, volume_id),
          {:ok, action} <- wait_for(action)
        do
          case action do
            %{"status" => "errored"} -> {:error, "Attaching volume #{name} to #{droplet_id} failed"}
            _ -> {:ok, action}
          end
        end
    end
  end

  defp mount(volume, letter \\ ?a)

  defp mount(%{"name" => vol_name}, letter) when letter > ?z do
    {:error, "No device found for #{vol_name}"}
  end
  defp mount(volume, letter) do
    device = "/mnt/dev/sd" <> <<letter>> # TODO fix this
    if File.exists?(device) do
      %{"name" => vol_name} = volume
      mountpoint = "/mnt/volumes/#{vol_name}"

      File.mkdir(mountpoint)

      {results, 0} = System.cmd("/bin/mount", [])

      if not (results =~ device) do
        {_result, 0} = System.cmd("/bin/mount", [device, mountpoint])
      end
    else
      mount(volume, letter+1)
    end
  end

  defp wait_for(action, statuses \\ ~w(completed errored)) do
    statuses = List.wrap(statuses)
    %{
      "id" => id,
      "type" => type,
      "status" => status,
      "resource_type" => resource_type,
    } = action

    if Enum.member?(statuses, status) do
      {:ok, action}
    else
      Logger.info("waiting on #{resource_type} #{type}")
      :timer.sleep(1000)
      case Api.action_get(id) do
        {:ok, action} -> wait_for(action, statuses)
        error -> error
      end
    end
  end

end
