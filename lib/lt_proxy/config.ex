defmodule LtProxy.Config do
  @moduledoc "Access to application settings, see `LtProxy.Settings`."

  @spec fetch!(atom()) :: term()
  def fetch!(key), do: LtProxy.Settings.get(key)
end
