defmodule LtProxyWeb.ApiEndpoint do
  use Phoenix.Endpoint, otp_app: :lt_proxy

  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug LtProxyWeb.Plugs.ParseBody
  plug LtProxyWeb.ApiRouter
end
