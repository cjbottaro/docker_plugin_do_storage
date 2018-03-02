defmodule DoStorage.AttacherTest do
  use ExUnit.Case

  import Mox
  setup :verify_on_exit!

  alias DoStorage.{Attacher, Volume, Api}

  test "attaching an unattached volume" do
    Volume.put(%Volume{name: "data"})

    attach_action = %{
      "action" => %{
        "id" => "00001",
        "type" => "attach_volume",
        "resource_type" => "backend"
      }
    }
    attach_url = "volumes/00001/actions"
    attach_params = [type: "attach", droplet_id: 1]

    HttpMock
      |> http_expect(:get!, "volumes", [name: "data"], fn ->
        %{"volumes" => [%{"id" => "00001", "droplet_ids" => []}]}
      end)
      |> http_expect(:post!, attach_url, attach_params, fn ->
        put_in(attach_action, ["action", "status"], "completed")
      end)

    {:ok, %{"type" => "attach_volume"}} = Attacher.attach("data", 1)

    # Same test, but with waiting.

    HttpMock
      |> http_expect(:get!, "volumes", [name: "data"], fn ->
        %{"volumes" => [%{"id" => "00001", "droplet_ids" => []}]}
      end)
      |> http_expect(:post!, attach_url, attach_params, fn ->
        put_in(attach_action, ["action", "status"], "in-progress")
      end)
      |> http_expect(:get!, "actions/00001", [], fn ->
        put_in(attach_action, ["action", "status"], "completed")
      end)

    {:ok, %{"type" => "attach_volume"}} = Attacher.attach("data", 1)
  end

  test "attaching a volume that's attached to another droplet" do
    Volume.put(%Volume{name: "data"})

    detach_action = %{
      "action" => %{
        "id" => "00001",
        "type" => "deattach_volume",
        "resource_type" => "backend"
      }
    }
    attach_action = %{
      "action" => %{
        "id" => "00002",
        "type" => "attach_volume",
        "resource_type" => "backend"
      }
    }
    detach_params = [type: "detach", droplet_id: 1]
    attach_params = [type: "attach", droplet_id: 2]

    HttpMock
      |> http_expect(:get!, "volumes", [name: "data"], fn ->
        %{"volumes" => [%{"id" => "00001", "droplet_ids" => [1]}]}
      end)
      |> http_expect(:post!, "volumes/00001/actions", detach_params, fn ->
        put_in(detach_action, ~w(action status), "completed")
      end)
      |> http_expect(:post!, "volumes/00001/actions", attach_params, fn ->
        put_in(attach_action, ~w(action status), "completed")
      end)

    {:ok, %{"type" => "attach_volume"}} = Attacher.attach("data", 2)

    # Same test, but with waiting on detach.

    HttpMock
      |> http_expect(:get!, "volumes", [name: "data"], fn ->
        %{"volumes" => [%{"id" => "00001", "droplet_ids" => [1]}]}
      end)
      |> http_expect(:post!, "volumes/00001/actions", detach_params, fn ->
        put_in(detach_action, ~w(action status), "in-progress")
      end)
      |> http_expect(:get!, "actions/00001", [], fn ->
        put_in(detach_action, ["action", "status"], "completed")
      end)
      |> http_expect(:post!, "volumes/00001/actions", attach_params, fn ->
        put_in(attach_action, ~w(action status), "completed")
      end)

    {:ok, %{"type" => "attach_volume"}} = Attacher.attach("data", 2)
  end

  test "we are already attached" do
    Volume.put(%Volume{name: "data"})

    HttpMock
      |> http_expect(:get!, "volumes", [name: "data"], fn ->
        %{"volumes" => [%{"id" => "00001", "droplet_ids" => [1]}]}
      end)

    {:ok, "already attached"} = Attacher.attach("data", 1)
  end

  defp http_expect(mock, :get!, path, params, block) do
    url = "#{Api.base_url}/#{path}"
    headers = Api.headers
    params = Keyword.merge(params, region: "nyc1")
    options = [params: params]
    expect(mock, :get!, fn ^url, ^headers, ^options ->
      %{body: Poison.encode!(block.())}
    end)
  end

  defp http_expect(mock, :post!, path, params, block) do
    url = "#{Api.base_url}/#{path}"
    headers = Api.headers
    body = params
      |> Keyword.merge(region: "nyc1")
      |> Map.new
      |> Poison.encode!
    expect(mock, :post!, fn ^url, ^body, ^headers ->
      %{body: Poison.encode!(block.())}
    end)
  end

end
