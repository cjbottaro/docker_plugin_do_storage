defmodule DoStorage.MounterTest do
  use ExUnit.Case

  import Mox
  setup :verify_on_exit!

  alias DoStorage.{Mounter, Volume}

  test "mounting on /dev/disk/by-id/scsi-0DO_Volume_data" do
    Volume.put(%Volume{name: "data"})

    device = "scsi-0DO_Volume_data"
    devices = ["scsi-0DO_Volume_foo", device]
    device_path = "/mnt/dev/disk/by-id/#{device}"

    FileMock
      |> expect(:dir?, fn "/mnt/dev/disk/by-id" -> true end)
      |> expect(:ls, fn "/mnt/dev/disk/by-id" -> {:ok, devices} end)
      |> expect(:mkdir, fn "/mnt/volumes/data" -> :ok end)

    SystemMock
      |> expect(:cmd, fn "mount", [] -> {"/mnt/dev/xvda on /", 0} end)
      |> expect(:cmd, fn "mount", [^device_path, "/mnt/volumes/data"] -> {"", 0} end)

    assert {:ok, volume} = Mounter.mount("data")
    assert volume.mountpoint == "/mnt/volumes/data"
  end
end
