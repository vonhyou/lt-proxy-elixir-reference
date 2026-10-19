defmodule LtProxyWeb.Layouts do
  @moduledoc "Root and app layouts for the admin panel."
  use LtProxyWeb, :html

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <.live_title default="LtProxy" suffix=" · LtProxy">
          {assigns[:page_title]}
        </.live_title>
        <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
        <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
        </script>
      </head>
      <body class="bg-base-200 text-base-content antialiased">
        {@inner_content}
      </body>
    </html>
    """
  end

  attr :flash, :map, required: true
  attr :current, :atom, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :actions
  slot :inner_block, required: true

  def app(assigns) do
    assigns =
      assign(assigns, :nav, [
        {:dashboard, "Dashboard", ~p"/", "hero-squares-2x2"},
        {:keys, "API keys", ~p"/keys", "hero-key"},
        {:settings, "Settings", ~p"/settings", "hero-adjustments-horizontal"}
      ])

    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="nav-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex min-h-screen flex-col">
        <header class="navbar gap-2 border-b border-base-300 bg-base-100 lg:hidden">
          <label for="nav-drawer" class="btn btn-square btn-ghost" aria-label="Open menu">
            <.icon name="hero-bars-3" class="size-5" />
          </label>
          <.brand />
        </header>
        <main class="flex-1 px-4 py-6 sm:px-6 lg:px-10 lg:py-8">
          <div class="mx-auto max-w-5xl space-y-6">
            <div class="flex flex-wrap items-end justify-between gap-4">
              <div>
                <h1 class="text-2xl font-semibold tracking-tight">{@title}</h1>
                <p :if={@subtitle} class="mt-1 text-sm text-base-content/60">{@subtitle}</p>
              </div>
              <div class="flex items-center gap-3">
                {render_slot(@actions)}
                <span class="flex items-center gap-2 text-xs text-base-content/60">
                  <span class="size-2 rounded-full bg-success [.phx-error_&]:bg-warning"></span>
                  <span class="[.phx-error_&]:hidden">Live</span>
                  <span id="reconnecting" class="hidden [.phx-error_&]:inline">Reconnecting…</span>
                </span>
              </div>
            </div>
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
      <div class="drawer-side z-40">
        <label for="nav-drawer" class="drawer-overlay" aria-label="Close menu"></label>
        <aside class="flex min-h-full w-60 flex-col border-r border-base-300 bg-base-100">
          <div class="px-5 py-5"><.brand /></div>
          <ul class="menu w-full gap-0.5 px-3">
            <li :for={{id, label, path, icon} <- @nav}>
              <.link navigate={path} class={id == @current && "menu-active"}>
                <.icon name={icon} class="size-5" />{label}
              </.link>
            </li>
          </ul>
          <p class="mt-auto px-5 py-4 text-xs text-base-content/50">
            LtProxy {Application.spec(:lt_proxy, :vsn)}
          </p>
        </aside>
      </div>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  defp brand(assigns) do
    ~H"""
    <span class="flex items-center gap-2.5 font-semibold">
      <span class="grid size-8 place-items-center rounded-lg bg-primary text-primary-content">
        <.icon name="hero-language" class="size-5" />
      </span>
      LtProxy
    </span>
    """
  end

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
