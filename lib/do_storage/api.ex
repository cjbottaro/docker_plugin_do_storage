defmodule DoStorage.Api do
  require Logger
  alias DoStorage.Metadata

  @base_url "https://api.digitalocean.com/v2"

  def retrieve_volume(name) do
    get("volumes", name: name)
  end

  defp get(path, params \\ [])

  defp get(path, params) do
    url = "#{@base_url}/#{path}"
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token()}"}
    ]
    params = Keyword.merge(params, region: Metadata.region)
    response = HTTPoison.get!(url, headers, params: params)
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
