defmodule DoStorage.Api do
  require Logger
  alias DoStorage.Metadata

  @base_url "https://api.digitalocean.com/v2"

  def volume_get(name) do
    case get("volumes", name: name) do
      %{"volumes" => []} -> {:error, "volume #{name} not found"}
      %{"volumes" => [volume | []]} -> {:ok, volume}
    end
  end

  def volume_attach(droplet_id, volume_id) do
    params = [
      type: "attach",
      droplet_id: droplet_id
    ]
    case post("volumes/#{volume_id}/actions", params) do
      %{"id" => "invalid", "message" => message} -> {:error, message}
      %{"action" => action} -> {:ok, action}
    end
  end

  def volume_detach(droplet_id, volume_id) do
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

  def action_get(id) do
    case get("actions/#{id}") do
      %{"message" => message} -> {:error, message}
      %{"action" => action} -> {:ok, action}
    end
  end

  def get(path, params \\ [])

  def get(path, params) do
    url = "#{@base_url}/#{path}"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token()}"}
    ]
    params = Keyword.merge(params, region: Metadata.region)
    response = HTTPoison.get!(url, headers, params: params)
    Poison.decode!(response.body)
  end

  def post(path, params) do
    url = "#{@base_url}/#{path}"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token()}"}
    ]
    params = Keyword.merge(params, region: Metadata.region) |> Map.new
    response = HTTPoison.post!(url, Poison.encode!(params), headers)
    Poison.decode!(response.body)
  end

  defp token do
    token = System.get_env("ACCESS_TOKEN")
    if token == nil || token == "" do
      Logger.error "ACCESS_TOKEN not set; install plugin with ACCESS_TOKEN=<your_token>"
    end
    token
  end

end
