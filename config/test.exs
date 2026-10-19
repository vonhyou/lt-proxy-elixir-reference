import Config

config :lt_proxy,
  require_api_keys: false,
  slot_wait_ms: 0,
  provider_key: "test-provider-key",
  data_dir: Path.join(System.tmp_dir!(), "lt_proxy_test_#{System.os_time()}"),
  req_options: [plug: {Req.Test, LtProxy.Upstream}, retry: false]

config :lt_proxy, LtProxyWeb.ApiEndpoint, server: false

# Admin endpoint
config :lt_proxy,
  admin_password: "test-admin-password",
  admin_hosts: ["localhost"],
  admin_failed_delay_ms: 50

config :lt_proxy, LtProxyWeb.AdminEndpoint,
  server: false,
  secret_key_base: "v4K2ABYbJxIs4atkZJgrUgwjmdIwk5NJgYLZ8/BETMw39f40u9KHM96YpyKvmpcN"
