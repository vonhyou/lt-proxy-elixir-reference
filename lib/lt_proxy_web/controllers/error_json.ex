defmodule LtProxyWeb.ErrorJSON do
  def render("404.json", _assigns), do: %{error: "Not found"}

  def render(template, _assigns),
    do: %{error: Phoenix.Controller.status_message_from_template(template)}
end
