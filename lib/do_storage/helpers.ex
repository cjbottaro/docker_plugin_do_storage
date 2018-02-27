defmodule DoStorage.Helpers do

  def get_env(key, default) do
    Application.get_env(:do_storage, key, default)
  end

end
