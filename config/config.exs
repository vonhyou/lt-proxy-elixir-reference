import Config

config :lt_proxy,
  provider: LtProxy.Provider.OpenRouter,
  provider_key: nil,
  provider_url: "https://openrouter.ai/api/v1",
  model: "anthropic/claude-haiku-5.5",
  zdr: true,
  upstream_timeout_ms: 15_000,
  max_concurrency: 4,
  cache_ttl_hours: 24 * 7,
  cache_limit: 10_000,
  rpm: nil,
  port: 5000,
  bind: "0.0.0.0",
  admin_port: 5001,
  admin_bind: "127.0.0.1",
  admin_hosts: ["localhost", "127.0.0.1"],
  admin_password: nil,
  data_dir: "data"

config :lt_proxy, LtProxyWeb.ApiEndpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: LtProxyWeb.ErrorJSON], layout: false],
  server: true

config :lt_proxy, LtProxyWeb.AdminEndpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 5001],
  server: true,
  render_errors: [formats: [html: LtProxyWeb.ErrorHTML], layout: false],
  pubsub_server: LtProxy.PubSub,
  live_view: [signing_salt: "q7Rk2xVw"]

config :logger, :default_formatter, metadata: [:key]

config :phoenix, :json_library, JSON

config :esbuild,
  version: "0.25.4",
  lt_proxy: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.3.3",
  lt_proxy: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

import_config "#{config_env()}.exs"
