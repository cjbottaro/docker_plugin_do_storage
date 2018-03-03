defmodule DoStorage.Mounter do
  alias DoStorage.Volume
  import DoStorage.Helpers

  @devices_dir "/mnt/dev/disk/by-id"
  @mount_root "/mnt/volumes"
  @device_prefix "scsi-0DO_Volume_"

  @file_mod get_env(:file, File)
  @system get_env(:system, System)

  def mount(name) when is_binary(name) do
    with {:ok, volume} <- Volume.get(name),
    do: mount(volume)
  end

  def mount(%Volume{} = volume) do
    with {:ok, device} <- get_device(volume.name),
      {:ok, mountpoint} <- do_mount(device, volume.name)
    do
      %{volume | mountpoint: mountpoint} |> Volume.put
    end
  end

  def umount(name) when is_binary(name) do
    with {:ok, volume} <- Volume.get(name),
    do: umount(volume)
  end

  def umount(%Volume{name: name, mountpoint: nil}) do
    {:error, "volume (internal) #{name} has no mountpoint"}
  end

  def umount(%Volume{} = volume) do
    with {:ok, device} when not is_nil(device) <- mount_status(volume.mountpoint),
      {_output, 0} <- @system.cmd("umount", [volume.mountpoint])
    do
      volume = %{volume | mountpoint: nil} |> Volume.put
      {:ok, volume}
    else
      {:ok, nil} ->
        volume = %{volume | mountpoint: nil} |> Volume.put
        {:ok, volume}
      {reason, code} when is_integer(code) ->
        {:error, reason}
    end
  end

  defp get_device(name) do
    if @file_mod.dir?(@devices_dir) do
      scan_devices_dir(name)
    else
      {:error, "/dev/disk/by-id does not exist"}
    end
  end

  defp scan_devices_dir(name) do
    with {:ok, devices} = @file_mod.ls(@devices_dir),
      device when not is_nil(device) <- Enum.find(devices, fn device ->
        String.replace_prefix(device, @device_prefix, "") == name
      end)
    do
      {:ok, "#{@devices_dir}/#{device}"}
    else
      {:error, _} = error -> error
      nil -> {:error, "no device found for #{name}"}
    end
  end

  defp do_mount(device, name) do
    mountpoint = "#{@mount_root}/#{name}"
    with {:ok, nil} <- mount_status(mountpoint),
      :ok <- mkdir(mountpoint),
      {_output, 0} <- @system.cmd("mount", [device, mountpoint])
    do
      {:ok, mountpoint}
    else
      {:ok, ^device} -> {:ok, mountpoint}
      {:ok, device} -> {:error, "#{device} already mounted on #{mountpoint}"}
      {reason, code} when is_integer(code) -> {:error, reason}
    end
  end

  defp mount_status(mountpoint) do
    with {output, 0} <- @system.cmd("mount", []) do
      device = output
        |> String.split("\n")
        |> Enum.find_value(fn line ->
          case String.split(line) do
            [] -> false
            [device | tokens] ->
              Enum.any?(tokens, &String.ends_with?(&1, mountpoint)) && device
          end
        end)
      {:ok, device}
    else
      {reason, code} when is_integer(code) -> {:error, reason}
    end
  end

  def mkdir(dir) do
    case @file_mod.mkdir(dir) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, reason} -> {:error, "mkdir #{dir} failed: #{reason}"}
    end
  end

end
