defmodule DoStorage.Metadata do

  @base_url "http://169.254.169.254/metadata/v1"

  def id, do: get_metadata("id")
  def region, do: System.get_env("DO_REGION") || get_metadata("region")

  def get_metadata(path) do
    url = "#{@base_url}/#{path}"

    case HTTPoison.get(url) do
      {:error, %{reason: :connect_timeout}} -> nil
      {:ok, response} -> response.body
    end
  end

end
