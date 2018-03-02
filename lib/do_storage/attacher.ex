defmodule DoStorage.Attacher do
  alias DoStorage.{Api}

  def attach(name, droplet_id) do
    with {:ok, volume} <- Api.volume_get(name),
      {:ok, _} <- detach_others(volume, droplet_id),
    do: attach_me(volume, droplet_id)
  end

  def detach(name) when is_binary(name) do
    with {:ok, volume} <- Api.volume_get(name),
    do: detach(volume)
  end

  def detach(%{"droplet_ids" => []}), do: {:ok, "not attached"}
  def detach(%{"id" => id, "droplet_ids" => [droplet_id | []]}) do
    with {:ok, action} <- Api.volume_detach(id, droplet_id),
    do: Api.wait(action)
  end

  defp detach_others(volume, droplet_id) do
    if Enum.member?(volume["droplet_ids"], droplet_id) do
      {:ok, "already attached"}
    else
      detach(volume)
    end
  end

  defp attach_me(volume, droplet_id) do
    %{"id" => volume_id, "droplet_ids" => droplet_ids} = volume
    if Enum.member?(droplet_ids, droplet_id) do
      {:ok, "already attached"}
    else
      with {:ok, action} <- Api.volume_attach(volume_id, droplet_id),
      do: Api.wait(action)
    end
  end

end
