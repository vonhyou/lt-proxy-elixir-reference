import Config

if config_env() != :test do
  alias LtProxy.Config.Env

  env = Env.read()
  fetch = if config_env() == :prod, do: &System.fetch_env!/1, else: &System.get_env/1
  admin_password = System.get_env("LTP_ADMIN_PASSWORD")
  secret_key_base = System.get_env("SECRET_KEY_BASE")

  config :lt_proxy, [env_keys: Keyword.keys(env)] ++ env

  config :lt_proxy,
    openrouter_key: fetch.("OPENROUTER_API_KEY"),
    admin_password: admin_password

  config :lt_proxy, LtProxyWeb.ApiEndpoint,
    http: [ip: Env.ip!(env[:bind] || "0.0.0.0"), port: env[:port] || 5000]

  config :lt_proxy, LtProxyWeb.AdminEndpoint,
    http: [ip: Env.ip!(env[:admin_bind] || "127.0.0.1"), port: env[:admin_port] || 5001]

  cond do
    secret_key_base && byte_size(secret_key_base) >= 64 ->
      config :lt_proxy, LtProxyWeb.AdminEndpoint, secret_key_base: secret_key_base

    admin_password not in [nil, ""] and (secret_key_base || config_env() == :prod) ->
      raise "SECRET_KEY_BASE (at least 64 bytes) is required when LTP_ADMIN_PASSWORD is set; " <>
              "generate one with: openssl rand -base64 48"

    true ->
      :ok
  end
end
