defmodule LtProxyWeb.CoreComponents do
  @moduledoc "UI building blocks for the admin pages (daisyUI + Heroicons)."
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :id, :string
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error]
  attr :rest, :global
  slot :inner_block

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> JS.hide(to: "##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label="close">
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text", values: ~w(checkbox number text textarea)
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :checked, :boolean
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(autocomplete disabled form max maxlength min minlength pattern placeholder
                readonly required rows step)

  slot :help

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error/1))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <fieldset class="fieldset">
      <legend :if={@label} class="fieldset-legend">{@label}</legend>
      <label class="label cursor-pointer gap-3">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class || "toggle"}
          {@rest}
        />
        {render_slot(@help)}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <fieldset class="fieldset">
      <legend :if={@label} class="fieldset-legend">{@label}</legend>
      <textarea
        id={@id}
        name={@name}
        aria-label={@label}
        class={[@class || "textarea w-full", @errors != [] && "textarea-error"]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <p :if={@help != []} class="label">{render_slot(@help)}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(assigns) do
    ~H"""
    <fieldset class="fieldset">
      <legend :if={@label} class="fieldset-legend">{@label}</legend>
      <input
        type={@type}
        name={@name}
        id={@id}
        aria-label={@label}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[@class || "input w-full", @errors != [] && "input-error"]}
        {@rest}
      />
      <p :if={@help != []} class="label">{render_slot(@help)}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="label text-error">
      <.icon name="hero-exclamation-circle" class="size-4" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  defp translate_error({msg, _opts}), do: msg
end
