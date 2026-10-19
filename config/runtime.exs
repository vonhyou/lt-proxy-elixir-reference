import Config

if config_env() != :test do
  alias LtProxy.Config.Env

  env = Env.read()
  prod? = config_env() == :prod
  blank = fn var -> with "" <- System.get_env(var), do: nil end
  require! = fn var, value -> value || raise("#{var} is required") end

  provider = LtProxy.Provider.fetch!(env[:provider] || "openrouter")
  provider_key = blank.("LTP_PROVIDER_KEY")
  if prod? and is_nil(provider_key), do: raise("LTP_PROVIDER_KEY is required")
  provider_url = require!.("LTP_PROVIDER_URL", env[:provider_url] || provider.default_url())
  model = require!.("LTP_MODEL", env[:model] || provider.default_model())
  secret_key_base = blank.("SECRET_KEY_BASE")
  admin_password = blank.("LTP_ADMIN_PASSWORD")

  if admin_password && byte_size(admin_password) < 16,
    do: raise("LTP_ADMIN_PASSWORD must be at least 16 characters")

  config :lt_proxy, [env_keys: Keyword.keys(env)] ++ env

  config :lt_proxy,
    provider: provider,
    provider_key: provider_key,
    provider_url: provider_url,
    model: model,
    admin_password: admin_password

  config :lt_proxy, LtProxyWeb.ApiEndpoint,
    http: [ip: Env.ip!(env[:bind] || "0.0.0.0"), port: env[:port] || 5000]

  config :lt_proxy, LtProxyWeb.AdminEndpoint,
    http: [ip: Env.ip!(env[:admin_bind] || "127.0.0.1"), port: env[:admin_port] || 5001]

  if secret_key_base do
    if byte_size(secret_key_base) < 64, do: raise("SECRET_KEY_BASE must be at least 64 bytes")
    config :lt_proxy, LtProxyWeb.AdminEndpoint, secret_key_base: secret_key_base
  end
end
