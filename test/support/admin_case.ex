defmodule LtProxyWeb.AdminCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint LtProxyWeb.AdminEndpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import LtProxyWeb.AdminCase
    end
  end

  setup do
    {:ok, conn: %{Phoenix.ConnTest.build_conn() | host: "localhost"}}
  end

  def authorize(conn, password \\ Application.fetch_env!(:lt_proxy, :admin_password)) do
    Plug.Conn.put_req_header(
      conn,
      "authorization",
      Plug.BasicAuth.encode_basic_auth("admin", password)
    )
  end
end
