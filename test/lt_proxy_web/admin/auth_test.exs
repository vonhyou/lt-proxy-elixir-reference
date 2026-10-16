defmodule LtProxyWeb.Admin.AuthTest do
  use LtProxyWeb.AdminCase, async: false

  alias LtProxyWeb.AdminAuth

  test "no credentials returns 401", %{conn: conn} do
    conn = get(conn, "/")
    assert conn.status == 401
    assert get_resp_header(conn, "www-authenticate") != []
  end

  test "wrong password returns 401", %{conn: conn} do
    assert conn |> authorize("nope") |> get("/") |> Map.fetch!(:status) == 401
  end

  test "wrong host returns 400 before auth", %{conn: conn} do
    conn = %{conn | host: "evil.example"} |> authorize() |> get("/")
    assert conn.status == 400
  end

  test "authorized request sets the admin session flag and security headers", %{conn: conn} do
    conn = conn |> authorize() |> get("/")
    assert conn.status == 200
    assert get_session(conn, :admin) == AdminAuth.session_token()
    assert [csp] = get_resp_header(conn, "content-security-policy")
    assert csp =~ "default-src 'self'"
  end

  test "on_mount halts without the session flag" do
    socket = %Phoenix.LiveView.Socket{}

    assert {:halt, %{redirected: {:redirect, %{to: "/"}}}} =
             AdminAuth.on_mount(:default, %{}, %{}, socket)

    assert {:halt, _} = AdminAuth.on_mount(:default, %{}, %{"admin" => "yes"}, socket)
    assert {:halt, _} = AdminAuth.on_mount(:default, %{}, %{"admin" => true}, socket)

    assert {:cont, ^socket} =
             AdminAuth.on_mount(:default, %{}, %{"admin" => AdminAuth.session_token()}, socket)
  end

  test "changing the password invalidates existing sessions" do
    socket = %Phoenix.LiveView.Socket{}
    session = %{"admin" => AdminAuth.session_token()}
    password = Application.fetch_env!(:lt_proxy, :admin_password)
    Application.put_env(:lt_proxy, :admin_password, "a-new-admin-password")
    on_exit(fn -> Application.put_env(:lt_proxy, :admin_password, password) end)

    assert {:halt, _} = AdminAuth.on_mount(:default, %{}, session, socket)
  end

  test "every admin route is guarded by the on_mount hook" do
    for path <- ~w(/ /settings) do
      %{phoenix_live_view: {_, _, _, %{extra: %{on_mount: hooks}}}} =
        Phoenix.Router.route_info(LtProxyWeb.AdminRouter, "GET", path, "localhost")

      assert Enum.any?(hooks, &match?(%{id: {AdminAuth, :default}}, &1))
    end
  end

  test "serves the favicon", %{conn: conn} do
    conn = conn |> authorize() |> get("/favicon.svg")
    assert conn.status == 200
    assert conn.resp_body =~ "<svg"
  end

  test "socket origin check uses the admin hosts" do
    assert AdminAuth.allowed_origin?(URI.parse("http://localhost:5001"))
    refute AdminAuth.allowed_origin?(URI.parse("http://evil.example"))
  end
end
