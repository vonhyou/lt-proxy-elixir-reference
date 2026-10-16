import Config

config :lt_proxy,
  api_key: nil,
  openrouter_key: nil,
  model: "anthropic/claude-haiku-5.5",
  zdr: true,
  port: 5000,
  server: true,
  upstream_timeout_ms: 15_000,
  max_concurrency: 4,
  cache_ttl_ms: :timer.hours(24 * 7),
  cache_limit: 10_000,
  max_body_bytes: 100_000,
  rpm: nil

import_config "#{config_env()}.exs"
