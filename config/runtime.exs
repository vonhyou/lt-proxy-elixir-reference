import Config

if config_env() != :test do
  fetch = if config_env() == :prod, do: &System.fetch_env!/1, else: &System.get_env/1
  int = &String.to_integer/1

  config :lt_proxy,
    api_key: fetch.("LTP_API_KEY"),
    openrouter_key: fetch.("OPENROUTER_API_KEY")

  optional = [
    model: {"LTP_MODEL", & &1},
    zdr: {"LTP_ZDR", &(&1 != "false")},
    port: {"LTP_PORT", int},
    upstream_timeout_ms: {"LTP_UPSTREAM_TIMEOUT_MS", int},
    max_concurrency: {"LTP_MAX_CONCURRENCY", int},
    cache_ttl_ms: {"LTP_CACHE_TTL_HOURS", &:timer.hours(int.(&1))},
    cache_limit: {"LTP_CACHE_LIMIT", int},
    max_body_bytes: {"LTP_MAX_BODY_BYTES", int},
    rpm: {"LTP_RPM", int}
  ]

  for {key, {var, parse}} <- optional, value = System.get_env(var) do
    config :lt_proxy, [{key, parse.(value)}]
  end
end
