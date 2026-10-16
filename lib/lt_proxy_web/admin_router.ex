defmodule LtProxyWeb.AdminRouter do
  use LtProxyWeb, :router

  @csp "default-src 'self'; img-src 'self' data:; base-uri 'self'; frame-ancestors 'none'"

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LtProxyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => @csp}
  end

  scope "/", LtProxyWeb do
    pipe_through :browser

    live_session :admin, on_mount: LtProxyWeb.AdminAuth do
      live "/", DashboardLive
      live "/settings", SettingsLive
    end
  end
end
