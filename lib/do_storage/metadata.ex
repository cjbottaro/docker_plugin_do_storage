defmodule DoStorage.Metadata do
  import DoStorage.Helpers

  @base_url "http://169.254.169.254/metadata/v1"

  def id, do: (System.get_env("DROPLET_ID") || get_metadata("id")) |> to_string |> String.to_integer
  def region, do: get_env(:region, nil) || get_metadata("region")

  def get_metadata(path) do
    url = "#{@base_url}/#{path}"

    case HTTPoison.get(url) do
      {:error, %{reason: :connect_timeout}} -> nil
      {:ok, response} -> response.body
    end
  end

end
