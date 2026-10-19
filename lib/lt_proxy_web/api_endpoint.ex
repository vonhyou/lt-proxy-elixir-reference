defmodule LtProxyWeb.ApiEndpoint do
  use Phoenix.Endpoint, otp_app: :lt_proxy

  # Room for the maximum text plus the other parameters, in either body encoding.
  @max_body 4 * LtProxy.Translate.Request.max_text_bytes()

  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: JSON,
    length: @max_body

  plug LtProxyWeb.ApiRouter
end
