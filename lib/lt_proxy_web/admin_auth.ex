defmodule LtProxyWeb.AdminAuth do
  @moduledoc "Host check, HTTP Basic auth and the LiveView `on_mount` guard for the admin endpoint."

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    cond do
      not allowed_host?(conn.host) ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "Bad host: add #{conn.host} to LTP_ADMIN_HOSTS")
        |> halt()

      authorized?(conn) ->
        conn |> fetch_session() |> put_session(:admin, session_token())

      true ->
        if Plug.BasicAuth.parse_basic_auth(conn) != :error, do: Process.sleep(failed_delay())
        conn |> Plug.BasicAuth.request_basic_auth(realm: "LtProxy admin") |> halt()
    end
  end

  def on_mount(:default, _params, session, socket) do
    if valid_token?(session["admin"]),
      do: {:cont, socket},
      else: {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
  end

  def allowed_origin?(%URI{host: host}), do: allowed_host?(host)

  # Hostnames need listing (DNS rebinding); IP literals and localhost are always fine.
  defp allowed_host?(nil), do: false

  defp allowed_host?(host) do
    host in ["localhost" | hosts()] or
      match?(
        {:ok, _ip},
        host
        |> String.trim_leading("[")
        |> String.trim_trailing("]")
        |> String.to_charlist()
        |> :inet.parse_address()
      )
  end

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

  # Slows down password guessing; wrong credentials cost a second per attempt.
  defp failed_delay, do: Application.get_env(:lt_proxy, :admin_failed_delay_ms, 1_000)

  defp hosts, do: Application.fetch_env!(:lt_proxy, :admin_hosts)
end
