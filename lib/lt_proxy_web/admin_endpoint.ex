defmodule LtProxyWeb.AdminEndpoint do
  use Phoenix.Endpoint, otp_app: :lt_proxy

  @session_options [
    store: :cookie,
    key: "_lt_proxy_admin",
    signing_salt: "fV3tq8Lm",
    same_site: "Strict"
  ]

  @socket_opts [
    connect_info: [session: @session_options],
    check_origin: {LtProxyWeb.AdminAuth, :allowed_origin?, []}
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: @socket_opts, longpoll: @socket_opts

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Session, @session_options
  plug LtProxyWeb.AdminAuth
  plug Plug.Static, at: "/", from: :lt_proxy, only: LtProxyWeb.static_paths()

  plug Plug.Head
  plug LtProxyWeb.AdminRouter

  def enabled?, do: Application.get_env(:lt_proxy, :admin_password) not in [nil, ""]
end
