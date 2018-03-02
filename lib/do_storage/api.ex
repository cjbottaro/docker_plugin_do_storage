defmodule DoStorage.Api do
  require Logger
  alias DoStorage.Metadata
  import DoStorage.Helpers

  @base_url "https://api.digitalocean.com/v2"

  @sleep get_env(:sleep, 1000)
  @http get_env(:http, HTTPoison)

  def base_url, do: @base_url

  def volume_get(name) do
    case get("volumes", name: name) do
      %{"message" => message} -> {:error, message}
      %{"volumes" => []} -> {:error, "volume #{name} not found"}
      %{"volumes" => [volume | []]} -> {:ok, volume}
    end
  end

  def volume_attach(volume_id, droplet_id) do
    params = [
      type: "attach",
      droplet_id: droplet_id
    ]
    case post("volumes/#{volume_id}/actions", params) do
      %{"id" => "invalid", "message" => message} -> {:error, message}
      %{"action" => action} -> {:ok, action}
    end
  end

  def volume_detach(volume_id, droplet_id) do
    params = [
      type: "detach",
      droplet_id: droplet_id
    ]
    case post("volumes/#{volume_id}/actions", params) do
      %{"message" => message} -> {:error, message}
      %{"action" => action} -> {:ok, action}
    end
  end

  def volume_action(volume_id, action_id) do
    get("volumes/#{volume_id}/actions/#{action_id}")
      |> Access.get("action")
  end

  def wait(action) do
    %{
      "id" => id,
      "type" => type,
      "status" => status,
      "resource_type" => resource_type,
    } = action

    if Enum.member?(~w(completed errored), status) do
      {:ok, action}
    else
      Logger.info("waiting on #{resource_type} #{type}")
      :timer.sleep(@sleep)
      case action_get(id) do
        {:ok, action} -> wait(action)
        error -> error
      end
    end
  end

  def action_get(id) do
    case get("actions/#{id}") do
      %{"message" => message} -> {:error, message}
      %{"action" => action} -> {:ok, action}
    end
  end

  def get(path, params \\ [])

  def get(path, params) do
    url = "#{@base_url}/#{path}"
    params = Keyword.merge(params, region: Metadata.region)
    response = @http.get!(url, headers(), params: params)
    Poison.decode!(response.body)
  end

  def post(path, params) do
    url = "#{@base_url}/#{path}"
    params = Keyword.merge(params, region: Metadata.region) |> Map.new
    response = @http.post!(url, Poison.encode!(params), headers())
    Poison.decode!(response.body)
  end

  def headers do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token()}"}
    ]
  end

  defp token do
    token = get_env(:access_token, System.get_env("ACCESS_TOKEN"))
    if token == nil || token == "" do
      Logger.error "ACCESS_TOKEN not set; install plugin with ACCESS_TOKEN=<your_token>"
    end
    token
  end

end
