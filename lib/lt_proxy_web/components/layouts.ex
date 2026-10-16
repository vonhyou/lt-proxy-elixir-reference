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
        <.live_title default="LtProxy admin" suffix=" · LtProxy admin">
          {assigns[:page_title]}
        </.live_title>
        <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
        <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
        <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
        </script>
      </head>
      <body>
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
        {:settings, "Settings", ~p"/settings", "hero-adjustments-horizontal"}
      ])

    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="nav-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex min-h-screen flex-col bg-base-200">
        <header class="navbar border-b border-base-300 bg-base-100 lg:hidden">
          <label for="nav-drawer" class="btn btn-square btn-ghost" aria-label="Open menu">
            <.icon name="hero-bars-3" class="size-5" />
          </label>
          <.brand />
        </header>
        <main class="flex-1 p-4 sm:p-6 lg:p-8">
          <div class="mx-auto max-w-5xl space-y-6">
            <div class="flex flex-wrap items-end justify-between gap-4">
              <div>
                <h1 class="flex items-center gap-3 text-2xl font-semibold">
                  {@title}
                  <span
                    id="reconnecting"
                    class="badge badge-warning hidden [.phx-error_&]:inline-flex"
                  >
                    Reconnecting…
                  </span>
                </h1>
                <p :if={@subtitle} class="text-sm text-base-content/60">{@subtitle}</p>
              </div>
              <div class="flex items-center gap-2">{render_slot(@actions)}</div>
            </div>
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
      <div class="drawer-side z-40">
        <label for="nav-drawer" class="drawer-overlay" aria-label="Close menu"></label>
        <aside class="min-h-full w-60 border-r border-base-300 bg-base-100">
          <div class="px-6 py-5"><.brand /></div>
          <ul class="menu w-full gap-1 px-3">
            <li :for={{id, label, path, icon} <- @nav}>
              <.link navigate={path} class={id == @current && "menu-active"}>
                <.icon name={icon} class="size-5" />{label}
              </.link>
            </li>
          </ul>
        </aside>
      </div>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  defp brand(assigns) do
    ~H"""
    <span class="flex items-center gap-2 text-lg font-semibold">
      <.icon name="hero-language" class="size-6 text-primary" /> LtProxy
      <span class="badge badge-sm badge-soft badge-primary">admin</span>
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
