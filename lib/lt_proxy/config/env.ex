defmodule LtProxy.Config.Env do
  @moduledoc "Parses `LTP_*` environment variables; used by `config/runtime.exs`."

  @vars [
    provider: {"LTP_PROVIDER", :string},
    provider_url: {"LTP_PROVIDER_URL", :string},
    model: {"LTP_MODEL", :string},
    zdr: {"LTP_ZDR", :bool},
    port: {"LTP_PORT", :int},
    bind: {"LTP_BIND", :string},
    admin_port: {"LTP_ADMIN_PORT", :int},
    admin_bind: {"LTP_ADMIN_BIND", :string},
    admin_hosts: {"LTP_ADMIN_HOSTS", :list},
    upstream_timeout_ms: {"LTP_UPSTREAM_TIMEOUT_MS", :int},
    max_concurrency: {"LTP_MAX_CONCURRENCY", :int},
    cache_ttl_hours: {"LTP_CACHE_TTL_HOURS", :int},
    cache_limit: {"LTP_CACHE_LIMIT", :int},
    rpm: {"LTP_RPM", :int},
    data_dir: {"LTP_DATA_DIR", :string}
  ]

  @doc "Settings given by environment variables that are set and non-empty."
  @spec read() :: keyword()
  def read do
    for {key, {var, type}} <- @vars,
        value = System.get_env(var),
        value not in [nil, ""],
        do: {key, parse(type, value)}
  end

  @doc "Parses an IP address string, raising on invalid input."
  @spec ip!(String.t()) :: :inet.ip_address()
  def ip!(address) do
    case :inet.parse_address(String.to_charlist(address)) do
      {:ok, ip} -> ip
      {:error, _} -> raise ArgumentError, "invalid IP address: #{inspect(address)}"
    end
  end

  defp parse(:string, value), do: value
  defp parse(:list, value), do: value |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
  defp parse(:bool, value), do: value != "false"
  defp parse(:int, value), do: String.to_integer(value)
end
