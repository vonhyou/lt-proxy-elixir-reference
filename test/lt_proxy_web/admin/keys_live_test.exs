defmodule LtProxyWeb.Admin.KeysLiveTest do
  use LtProxyWeb.AdminCase, async: false

  alias LtProxy.ApiKeys

  setup %{conn: conn} do
    path = Path.join(Application.fetch_env!(:lt_proxy, :data_dir), "api_keys.json")
    File.rm(path)
    Application.put_env(:lt_proxy, :require_api_keys, true)
    ApiKeys.load!()

    on_exit(fn ->
      Application.put_env(:lt_proxy, :require_api_keys, false)
      File.rm(path)
      ApiKeys.load!()
    end)

    {:ok, view, _html} = conn |> authorize() |> live("/keys")
    %{view: view}
  end

  test "creates a key, shows it once and revokes it", %{view: view} do
    assert has_element?(view, "#keys-empty")

    html = view |> form("#key-form", key: %{name: "sharkey"}) |> render_submit()
    assert [key] = Regex.run(~r/ltp_[\w-]{32}/, html)
    assert has_element?(view, "#new-key-value[value='#{key}']")
    assert has_element?(view, "#key-sharkey td", "sharkey")
    assert {:ok, "sharkey"} = ApiKeys.authenticate(key)

    assert has_element?(view, "#key_name[value='']")
    assert view |> element("#key-sharkey") |> render() =~ String.slice(key, 0, 8)
    refute view |> element("#key-sharkey") |> render() =~ key

    assert view |> form("#key-form", key: %{name: "sharkey"}) |> render_submit() =~
             "already exists"

    view |> element("#key-sharkey button", "Revoke") |> render_click()
    refute has_element?(view, "#key-sharkey")
    assert has_element?(view, "#keys-empty")
    assert :error = ApiKeys.authenticate(key)
  end

  test "env keys are read-only", %{view: _view, conn: conn} do
    System.put_env("LTP_API_KEYS", "env:" <> String.duplicate("e", 24))
    on_exit(fn -> System.delete_env("LTP_API_KEYS") end)
    ApiKeys.load!()

    {:ok, view, _html} = conn |> authorize() |> live("/keys")
    assert has_element?(view, "#key-env .badge", "env")
    refute has_element?(view, "#key-env button", "Revoke")
  end
end
