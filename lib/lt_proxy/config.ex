defmodule LtProxy.Config do
  @moduledoc "Access to application settings, see `config/runtime.exs`."

  @spec fetch!(atom()) :: term()
  def fetch!(key), do: Application.fetch_env!(:lt_proxy, key)
end
