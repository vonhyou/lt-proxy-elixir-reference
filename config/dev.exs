import Config

config :lt_proxy, require_api_keys: false

# Admin endpoint
config :lt_proxy, LtProxyWeb.AdminEndpoint,
  secret_key_base: "Y870TBllu4REFS+jtDzpejzWwLoBi80nWj8YQbaRuJ9qjoGbygmY7AepTB7pPS01"
