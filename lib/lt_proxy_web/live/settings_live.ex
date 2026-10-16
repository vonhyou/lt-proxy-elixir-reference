defmodule LtProxyWeb.SettingsLive do
  use LtProxyWeb, :live_view

  alias LtProxy.Admin

  @labels %{
    zdr: "Zero data retention",
    upstream_timeout_ms: "Upstream timeout",
    rpm: "Rate limit",
    cache_ttl_ms: "Cache TTL",
    max_body_bytes: "Max body size",
    admin_hosts: "Admin hosts",
    data_dir: "Data directory",
    openrouter_key: "OpenRouter key"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Settings") |> load()}
  end

  @impl true
  def handle_event("validate", %{"settings" => params}, socket) do
    {:noreply, assign(socket, form: form(params, validate(params)))}
  end

  def handle_event("save", %{"settings" => params}, socket) do
    case Admin.update_settings(params) do
      :ok ->
        {:noreply, socket |> load() |> put_flash(:info, "Settings saved")}

      {:error, errors} ->
        {base, errors} = Map.pop(errors, :base)
        socket = assign(socket, form: form(params, errors))
        {:noreply, if(base, do: put_flash(socket, :error, base), else: socket)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current={:settings}
      title="Settings"
      subtitle="Changes apply immediately and are saved as overrides of the environment."
    >
      <div class="card card-border bg-base-100">
        <.form
          for={@form}
          id="settings-form"
          class="card-body"
          phx-change="validate"
          phx-submit="save"
        >
          <h2 class="card-title">Translation</h2>
          <div class="grid gap-x-6 sm:grid-cols-2">
            <div
              :for={s <- @editable}
              id={"setting-#{s.key}"}
              class={s.key in [:model, :zdr] && "sm:col-span-2"}
            >
              <.input
                :if={s.key == :zdr}
                field={@form[:zdr]}
                type="checkbox"
                label={label(:zdr)}
                class="toggle toggle-success"
              >
                <:help>
                  <span class="text-base-content">{hint(:zdr, nil)}</span>
                  <.source_badge source={s.source} />
                </:help>
              </.input>
              <.input
                :if={s.key != :zdr}
                field={@form[s.key]}
                type={if s.key == :model, do: "text", else: "number"}
                label={label(s.key)}
                min={s.key != :model && "1"}
                placeholder={s.key == :rpm && "unlimited"}
              >
                <:help>
                  <.source_badge source={s.source} />
                  {hint(s.key, @form[s.key].value)}
                </:help>
              </.input>
            </div>
          </div>
          <div class="card-actions justify-end pt-2">
            <button class="btn btn-primary" phx-disable-with="Saving…">
              <.icon name="hero-check" class="size-4" /> Save
            </button>
          </div>
        </.form>
      </div>

      <div class="card card-border bg-base-100">
        <div class="card-body">
          <h2 class="card-title">Read-only</h2>
          <p class="text-sm text-base-content/60">Set through the environment; restart to change.</p>
          <div class="overflow-x-auto">
            <table class="table">
              <tbody>
                <tr :for={s <- @read_only} id={"setting-#{s.key}"}>
                  <td class="w-1/3 text-base-content/70">{label(s.key)}</td>
                  <td class="font-mono break-all">{display(s.value)}</td>
                  <td class="text-right whitespace-nowrap">
                    <span :if={s.secret} class="badge badge-sm badge-soft badge-warning">secret</span>
                    <.source_badge source={s.source} />
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

  attr :source, :atom, required: true

  defp source_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm source",
      @source == :default && "badge-ghost",
      @source == :env && "badge-soft badge-info",
      @source == :file && "badge-soft badge-success"
    ]}>
      {if @source == :file, do: "override", else: @source}
    </span>
    """
  end

  defp hint(:model, _value), do: "OpenRouter model or @preset/…"
  defp hint(:zdr, _value), do: "Route only to zero-data-retention providers"
  defp hint(:upstream_timeout_ms, _value), do: "Time budget per upstream request, ms"
  defp hint(:max_concurrency, _value), do: "Concurrent upstream calls; excess get 503"
  defp hint(:rpm, _value), do: "Requests per minute; blank for unlimited"
  defp hint(:max_body_bytes, _value), do: "Request body limit, bytes"

  defp hint(:cache_ttl_ms, value) do
    case hours(value) do
      nil -> "Cache lifetime, ms"
      h -> "Cache lifetime, ms (≈ #{h} h)"
    end
  end

  defp load(socket) do
    {editable, read_only} = Enum.split_with(Admin.settings(), & &1.editable)
    params = Map.new(editable, &{Atom.to_string(&1.key), display(&1.value)})
    assign(socket, editable: editable, read_only: read_only, form: form(params, %{}))
  end

  defp form(params, errors) do
    to_form(params, as: :settings, errors: Enum.map(errors, fn {k, msg} -> {k, {msg, []}} end))
  end

  defp validate(params) do
    case Admin.validate_settings(params) do
      :ok -> %{}
      {:error, errors} -> errors
    end
  end

  defp hours(value) do
    case Integer.parse(to_string(value)) do
      {ms, ""} when ms > 0 -> Float.round(ms / 3_600_000, 2)
      _ -> nil
    end
  end

  defp display(nil), do: ""
  defp display(list) when is_list(list), do: Enum.join(list, ", ")

  defp display(value) when is_binary(value) or is_number(value) or is_boolean(value),
    do: to_string(value)

  defp display(value), do: inspect(value)

  defp label(key) do
    Map.get_lazy(@labels, key, fn ->
      key |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
    end)
  end
end
