import Config

config :logger, level: :info

config :lt_proxy, data_dir: "/app/data"

config :lt_proxy, LtProxyWeb.AdminEndpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"
