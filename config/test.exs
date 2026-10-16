import Config

config :lt_proxy,
  api_key: "test-key",
  openrouter_key: "test-openrouter-key",
  server: false,
  req_options: [plug: {Req.Test, LtProxy.Upstream}, retry: false]
