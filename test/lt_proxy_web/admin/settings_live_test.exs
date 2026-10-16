defmodule LtProxyWeb.Admin.SettingsLiveTest do
  use LtProxyWeb.AdminCase, async: false

  alias LtProxy.Admin

  setup %{conn: conn} do
    before = editable()

    on_exit(fn ->
      changed = Map.reject(before, fn {key, value} -> editable()[key] == value end)
      ExUnit.CaptureLog.capture_log(fn -> :ok = Admin.update_settings(changed) end)
    end)

    {:ok, view, _html} = conn |> authorize() |> live("/settings")
    %{view: view, before: before}
  end

  test "renders editable, read-only and secret rows with source badges", %{view: view} do
    assert has_element?(view, "#settings-form input[name='settings[model]']")
    assert has_element?(view, "#settings-form input[type=checkbox][name='settings[zdr]']")
    assert has_element?(view, "#setting-max_concurrency .source")
    assert has_element?(view, "#setting-admin_hosts td", "localhost")
    assert has_element?(view, "#setting-openrouter_key .badge", "secret")
    assert has_element?(view, "#setting-openrouter_key td", "••••-key")
    refute render(view) =~ "test-openrouter-key"
  end

  test "change validates live without saving", %{view: view, before: before} do
    html = view |> form("#settings-form", settings: %{rpm: "abc"}) |> render_change()
    assert html =~ "must be blank or a positive integer"
    assert editable() == before
  end

  test "an invalid value shows an inline error and saves nothing", %{view: view, before: before} do
    file = settings_file()
    on_disk = File.read(file)

    html =
      view
      |> form("#settings-form", settings: %{max_concurrency: "0", model: "other/model"})
      |> render_submit()

    assert html =~ "must be a positive integer"
    refute html =~ "Settings saved"
    assert editable() == before
    assert File.read(file) == on_disk
  end

  test "a valid save persists and applies", %{view: view, before: before} do
    max = String.to_integer(before["max_concurrency"]) + 1

    html =
      view
      |> form("#settings-form", settings: %{max_concurrency: max})
      |> render_submit()

    assert html =~ "Settings saved"
    assert Admin.status().max_concurrency == max
    assert has_element?(view, "#setting-max_concurrency .source", "override")
    assert settings_file() |> File.read!() |> JSON.decode!() |> Map.get("max_concurrency") == max
  end

  test "values render escaped", %{view: view} do
    html =
      view
      |> form("#settings-form", settings: %{model: "<script>alert(1)</script>"})
      |> render_submit()

    assert html =~ "&lt;script&gt;"
    refute html =~ "<script>alert"
  end

  defp editable do
    for %{editable: true, key: key, value: value} <- Admin.settings(), into: %{} do
      {Atom.to_string(key), if(is_nil(value), do: "", else: to_string(value))}
    end
  end

  defp settings_file,
    do: Path.join(Application.fetch_env!(:lt_proxy, :data_dir), "settings.json")
end
