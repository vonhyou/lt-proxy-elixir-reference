defmodule LtProxyWeb.DashboardLive do
  use LtProxyWeb, :live_view

  alias LtProxy.Admin

  @refresh_ms 2000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_ms, :refresh)

    {:ok,
     socket
     |> assign(page_title: "Dashboard", loading: false, result: nil)
     |> assign(form: to_form(%{"text" => "", "target" => "en"}, as: :test))
     |> refresh()}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, refresh(socket)}

  @impl true
  def handle_event("clear_cache", _params, socket) do
    :ok = Admin.clear_cache()
    {:noreply, socket |> put_flash(:info, "Cache cleared") |> refresh()}
  end

  def handle_event("change", %{"test" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: :test))}
  end

  def handle_event(
        "translate",
        %{"test" => %{"text" => text, "target" => target} = params},
        socket
      ) do
    {:noreply,
     socket
     |> assign(form: to_form(params, as: :test), loading: true, result: nil)
     |> start_async(:translate, fn -> Admin.test_translate(text, String.trim(target)) end)}
  end

  @impl true
  def handle_async(:translate, {:ok, result}, socket) do
    {:noreply, socket |> assign(loading: false, result: result) |> refresh()}
  end

  def handle_async(:translate, {:exit, _reason}, socket) do
    {:noreply, assign(socket, loading: false, result: {:error, :crashed})}
  end

  defp refresh(socket), do: assign(socket, status: Admin.status())

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current={:dashboard}
      title="Dashboard"
      subtitle="Refreshes every 2 seconds"
    >
      <div class="grid grid-cols-2 gap-px overflow-hidden rounded-box border border-base-300 bg-base-300 sm:grid-cols-4">
        <.stat id="stat-slots" label="In flight">
          {@status.slots_in_use}<span class="text-base-content/40"> / {@status.max_concurrency}</span>
        </.stat>
        <.stat id="stat-requests" label="Requests this minute">{@status.requests_this_minute}</.stat>
        <.stat id="stat-cache" label="Cached translations">{@status.cache_entries}</.stat>
        <.stat id="stat-uptime" label="Uptime">{format_uptime(@status.uptime_s)}</.stat>
      </div>

      <div class="grid gap-6 lg:grid-cols-3">
        <section class="card card-border bg-base-100 lg:col-span-2">
          <div class="card-body">
            <h2 class="card-title text-base">Try a translation</h2>
            <.form for={@form} id="test-form" phx-change="change" phx-submit="translate">
              <.input field={@form[:text]} type="textarea" label="Text" rows="4" />
              <div class="flex items-end gap-3">
                <.input field={@form[:target]} label="Target language" class="input w-28" />
                <button class="btn btn-primary mb-1" disabled={@loading}>
                  <span :if={@loading} class="loading loading-spinner loading-sm"></span> Translate
                </button>
              </div>
            </.form>

            <div
              :if={match?({:ok, _}, @result)}
              id="result"
              class="space-y-3 rounded-box bg-base-200 p-4"
            >
              <p id="result-text" class="whitespace-pre-wrap">{elem(@result, 1).text}</p>
              <p class="text-xs text-base-content/60">
                Detected {elem(@result, 1).lang || "und"} · {elem(@result, 1).ms} ms
              </p>
            </div>

            <div
              :if={match?({:error, _}, @result)}
              id="result-error"
              role="alert"
              class="alert alert-error alert-soft"
            >
              <.icon name="hero-exclamation-circle" class="size-5" />
              <span>{message(elem(@result, 1))}</span>
            </div>
          </div>
        </section>

        <section class="card card-border bg-base-100">
          <div class="card-body">
            <h2 class="card-title text-base">Translation setup</h2>
            <dl class="space-y-3 text-sm">
              <div>
                <dt class="text-base-content/60">Provider</dt>
                <dd id="stat-provider" class="font-medium">{@status.provider}</dd>
              </div>
              <div>
                <dt class="text-base-content/60">Model</dt>
                <dd id="stat-model" class="font-mono break-all">{@status.model}</dd>
              </div>
              <div>
                <dt class="text-base-content/60">Prompt version</dt>
                <dd id="stat-prompt" class="font-mono">{@status.prompt_version}</dd>
              </div>
            </dl>
            <div class="card-actions mt-auto pt-4">
              <button
                id="clear-cache"
                class="btn btn-soft btn-block"
                phx-click="clear_cache"
                data-confirm="Clear all cached translations? Clients will hit the model again."
              >
                <.icon name="hero-trash" class="size-4" /> Clear cache
              </button>
            </div>
          </div>
        </section>
      </div>

      <section class="card card-border bg-base-100">
        <div class="card-body">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <h2 class="card-title text-base">API keys</h2>
            <.link navigate={~p"/keys"} class="btn btn-sm btn-ghost">
              Manage keys <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
          <p :if={@status.keys == []} id="keys-empty" class="text-sm text-base-content/70">
            No API keys yet; clients cannot translate until you create one.
          </p>
          <div :if={@status.keys != []} class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Key</th>
                  <th class="text-right">Requests</th>
                  <th>Last used</th>
                </tr>
              </thead>
              <tbody id="keys">
                <tr :for={key <- @status.keys} id={"key-#{key.name}"}>
                  <td class="font-medium">{key.name}</td>
                  <td><code class="text-sm">{key.hint}</code></td>
                  <td class="text-right tabular">{key.requests}</td>
                  <td class="text-base-content/70">{format_time(key.last_used_at)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp stat(assigns) do
    ~H"""
    <div class="bg-base-100 px-5 py-4">
      <p class="text-xs text-base-content/60">{@label}</p>
      <p id={@id} class="stat-value mt-1 text-2xl font-semibold tracking-tight">
        {render_slot(@inner_block)}
      </p>
    </div>
    """
  end

  defp format_uptime(s) when s < 60, do: "#{s}s"
  defp format_uptime(s) when s < 3600, do: "#{div(s, 60)}m #{rem(s, 60)}s"
  defp format_uptime(s) when s < 86_400, do: "#{div(s, 3600)}h #{div(rem(s, 3600), 60)}m"

  defp format_uptime(s),
    do: "#{div(s, 86_400)}d #{div(rem(s, 86_400), 3600)}h #{div(rem(s, 3600), 60)}m"

  defp format_time(nil), do: "never"
  defp format_time(%DateTime{} = t), do: Calendar.strftime(t, "%Y-%m-%d %H:%M UTC")

  defp message(:missing_text), do: "Enter some text to translate."
  defp message(:too_long), do: "The text is too long."
  defp message(:missing_target), do: "Enter a target language."
  defp message(:invalid_lang), do: "Target must be a language code such as en or pt-BR."
  defp message(:empty_reply), do: "The model returned an empty reply."
  defp message({:transport, :timeout}), do: "The upstream request timed out."
  defp message({:transport, _}), do: "Could not reach the provider."
  defp message(:overloaded), do: "Too many translations in flight; try again shortly."
  defp message(:invalid_output), do: "The model returned output that could not be parsed."
  defp message(:crashed), do: "The translation crashed unexpectedly."
  defp message({:upstream_status, status}), do: "The provider returned HTTP #{status}."
  defp message(reason), do: "Translation failed: #{inspect(reason)}"
end
