defmodule LtProxyWeb.KeysLive do
  use LtProxyWeb, :live_view

  alias LtProxy.Admin

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "API keys", new_key: nil) |> load() |> reset_form()}
  end

  @impl true
  def handle_event("create", %{"key" => %{"name" => name}}, socket) do
    case Admin.create_key(name) do
      {:ok, key} ->
        {:noreply,
         socket |> assign(new_key: %{name: String.trim(name), key: key}) |> load() |> reset_form()}

      {:error, message} ->
        {:noreply,
         assign(socket, form: to_form(%{"name" => name}, as: :key, errors: [name: {message, []}]))}
    end
  end

  def handle_event("dismiss", _params, socket), do: {:noreply, assign(socket, new_key: nil)}

  def handle_event("revoke", %{"name" => name}, socket) do
    case Admin.revoke_key(name) do
      :ok -> {:noreply, socket |> put_flash(:info, "Key #{name} revoked") |> load()}
      {:error, message} -> {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current={:keys}
      title="API keys"
      subtitle="Each client gets its own key; revoking one takes effect immediately."
    >
      <div :if={@new_key} id="new-key" role="alert" class="alert alert-success alert-soft items-start">
        <.icon name="hero-key" class="size-5 mt-0.5" />
        <div class="min-w-0 flex-1 space-y-2">
          <p class="font-semibold">Key <span class="font-mono">{@new_key.name}</span> created</p>
          <p class="text-sm">Copy it now; it is shown only once.</p>
          <div class="join w-full">
            <input
              id="new-key-value"
              type="text"
              readonly
              value={@new_key.key}
              class="input join-item input-sm w-full font-mono"
              onclick="this.select()"
            />
            <button
              type="button"
              class="btn join-item btn-sm"
              phx-click={Phoenix.LiveView.JS.dispatch("ltp:copy", to: "#new-key-value")}
            >
              <.icon name="hero-clipboard" class="size-4" /> Copy
            </button>
          </div>
        </div>
        <button type="button" class="btn btn-ghost btn-sm" phx-click="dismiss" aria-label="Dismiss">
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>

      <div class="card card-border bg-base-100">
        <div class="card-body">
          <h2 class="card-title"><.icon name="hero-plus-circle" class="size-5" /> New key</h2>
          <.form
            for={@form}
            id="key-form"
            phx-submit="create"
            class="flex flex-wrap items-start gap-3"
          >
            <div class="min-w-56 flex-1">
              <.input
                field={@form[:name]}
                label="Name"
                placeholder="sharkey, translateyou, …"
                maxlength="32"
                autocomplete="off"
                required
              />
            </div>
            <button class="btn btn-primary mt-7" phx-disable-with="Creating…">Create key</button>
          </.form>
        </div>
      </div>

      <div class="card card-border bg-base-100">
        <div class="card-body">
          <h2 class="card-title"><.icon name="hero-key" class="size-5" /> Keys</h2>
          <p :if={@keys == []} id="keys-empty" class="text-sm text-base-content/70">
            No keys yet. Clients cannot translate until one exists.
          </p>
          <div :if={@keys != []} class="overflow-x-auto">
            <table class="table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Key</th>
                  <th>Created</th>
                  <th>Last used</th>
                  <th class="text-right">Requests</th>
                  <th></th>
                </tr>
              </thead>
              <tbody id="keys">
                <tr :for={key <- @keys} id={"key-#{key.name}"}>
                  <td class="font-medium">{key.name}</td>
                  <td>
                    <code class="text-sm">{key.hint}</code>
                    <span :if={key.source == :env} class="badge badge-sm badge-soft badge-info ml-2">env</span>
                  </td>
                  <td class="text-base-content/70">{format_date(key.created_at)}</td>
                  <td class="text-base-content/70">{format_time(key.last_used_at)}</td>
                  <td class="text-right tabular-nums">{key.requests}</td>
                  <td class="text-right">
                    <button
                      :if={key.source == :file}
                      class="btn btn-ghost btn-xs text-error"
                      phx-click="revoke"
                      phx-value-name={key.name}
                      data-confirm={"Revoke #{key.name}? Clients using it stop working immediately."}
                    >
                      Revoke
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load(socket), do: assign(socket, keys: Admin.status().keys)

  defp reset_form(socket), do: assign(socket, form: to_form(%{"name" => ""}, as: :key))

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = t), do: Calendar.strftime(t, "%Y-%m-%d")

  defp format_time(nil), do: "never"
  defp format_time(%DateTime{} = t), do: Calendar.strftime(t, "%Y-%m-%d %H:%M UTC")
end
