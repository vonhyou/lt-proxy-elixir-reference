defmodule LtProxyWeb.AdminAuth do
  @moduledoc "Host check, HTTP Basic auth and the LiveView `on_mount` guard for the admin endpoint."

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    cond do
      conn.host not in hosts() ->
        conn |> put_resp_content_type("text/plain") |> send_resp(400, "Bad host") |> halt()

      authorized?(conn) ->
        conn |> fetch_session() |> put_session(:admin, session_token())

      true ->
        conn |> Plug.BasicAuth.request_basic_auth(realm: "LtProxy admin") |> halt()
    end
  end

  def on_mount(:default, _params, session, socket) do
    if valid_token?(session["admin"]),
      do: {:cont, socket},
      else: {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
  end

  def allowed_origin?(%URI{host: host}), do: host in hosts()

  # Tied to the password, so changing it invalidates existing sessions and sockets.
  def session_token do
    secret = LtProxyWeb.AdminEndpoint.config(:secret_key_base)
    :crypto.mac(:hmac, :sha256, secret, password()) |> Base.url_encode64(padding: false)
  end

  defp valid_token?(token) when is_binary(token),
    do: Plug.Crypto.secure_compare(token, session_token())

  defp valid_token?(_token), do: false

  defp authorized?(conn) do
    case Plug.BasicAuth.parse_basic_auth(conn) do
      {user, pass} -> Plug.Crypto.secure_compare(digest(user, pass), digest("admin", password()))
      :error -> false
    end
  end

  defp digest(user, pass), do: :crypto.hash(:sha256, [user, 0, pass])

  defp password, do: Application.fetch_env!(:lt_proxy, :admin_password)

  defp hosts, do: Application.fetch_env!(:lt_proxy, :admin_hosts)
end
