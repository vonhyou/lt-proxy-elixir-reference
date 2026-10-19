defmodule LtProxyWeb.SettingsLive do
  use LtProxyWeb, :live_view

  alias LtProxy.{Admin, Upstream}

  @labels %{
    zdr: "Zero data retention",
    upstream_timeout_ms: "Provider timeout",
    rpm: "Rate limit",
    cache_ttl_hours: "Cache lifetime",
    admin_hosts: "Admin hosts",
    data_dir: "Data directory",
    provider_url: "Provider URL",
    provider_key: "Provider key"
  }

  @impl true
  def mount(_params, _session, socket) do
    socket = socket |> assign(page_title: "Settings", models: []) |> load()

    if connected?(socket),
      do: {:ok, start_async(socket, :models, &Upstream.models/0)},
      else: {:ok, socket}
  end

  @impl true
  def handle_async(:models, {:ok, {:ok, models}}, socket),
    do: {:noreply, assign(socket, models: models)}

  def handle_async(:models, _failed, socket), do: {:noreply, socket}

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
      subtitle="Changes apply immediately and override the environment until changed again."
    >
      <.form for={@form} id="settings-form" class="space-y-6" phx-change="validate" phx-submit="save">
        <section class="card card-border bg-base-100">
          <div class="card-body">
            <h2 class="card-title text-base">Model</h2>
            <p class="text-sm text-base-content/60">
              Provider <span class="font-medium text-base-content">{@provider}</span>, set by <code>LTP_PROVIDER</code>.
            </p>
            <div class="grid gap-x-6 sm:grid-cols-2">
              <.field
                :for={s <- @editable}
                :if={s.key in [:model, :zdr]}
                s={s}
                form={@form}
                models={@models}
              />
            </div>
          </div>
        </section>

        <section class="card card-border bg-base-100">
          <div class="card-body">
            <h2 class="card-title text-base">Limits</h2>
            <div class="grid gap-x-6 sm:grid-cols-2">
              <.field
                :for={s <- @editable}
                :if={s.key not in [:model, :zdr]}
                s={s}
                form={@form}
                models={[]}
              />
            </div>
            <div class="card-actions justify-end pt-2">
              <button class="btn btn-primary" phx-disable-with="Saving…">Save changes</button>
            </div>
          </div>
        </section>
      </.form>

      <section class="card card-border bg-base-100">
        <div class="card-body">
          <h2 class="card-title text-base">Environment</h2>
          <p class="text-sm text-base-content/60">Set when the service starts; restart to change.</p>
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
      </section>
    </Layouts.app>
    """
  end

  attr :s, :map, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :models, :list, required: true

  defp field(%{s: %{key: :zdr}} = assigns) do
    ~H"""
    <div id="setting-zdr" class="sm:col-span-2">
      <.input field={@form[:zdr]} type="checkbox" label={label(:zdr)} class="toggle toggle-success">
        <:help>
          <span class="text-base-content">{hint(:zdr, nil)}</span>
          <.source_badge source={@s.source} />
        </:help>
      </.input>
    </div>
    """
  end

  defp field(%{s: %{key: :model}} = assigns) do
    ~H"""
    <div id="setting-model" class="sm:col-span-2">
      <.input field={@form[:model]} label="Model" list="models" autocomplete="off">
        <:help>
          <.source_badge source={@s.source} />
          {hint(:model, nil)}
        </:help>
      </.input>
      <datalist id="models">
        <option :for={model <- @models} value={model}></option>
      </datalist>
    </div>
    """
  end

  defp field(assigns) do
    ~H"""
    <div id={"setting-#{@s.key}"}>
      <.input
        field={@form[@s.key]}
        type="number"
        label={label(@s.key)}
        min="1"
        placeholder={@s.key == :rpm && "unlimited"}
      >
        <:help>
          <.source_badge source={@s.source} />
          {hint(@s.key, @form[@s.key].value)}
        </:help>
      </.input>
    </div>
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

  defp hint(:model, _value), do: "Model id as the provider names it"
  defp hint(:zdr, _value), do: "Route only to providers that keep no data"
  defp hint(:upstream_timeout_ms, _value), do: "Milliseconds per request to the provider"
  defp hint(:max_concurrency, _value), do: "Requests to the provider at the same time"
  defp hint(:rpm, _value), do: "Requests per minute per key"

  defp hint(:cache_ttl_hours, _value), do: "Hours; 168 is one week"

  defp load(socket) do
    {editable, read_only} = Enum.split_with(Admin.settings(), & &1.editable)
    params = Map.new(editable, &{Atom.to_string(&1.key), display(&1.value)})
    provider = Enum.find_value(read_only, &(&1.key == :provider && &1.value))

    assign(socket,
      editable: editable,
      read_only: Enum.reject(read_only, &(&1.key == :provider)),
      provider: provider,
      form: form(params, %{})
    )
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
