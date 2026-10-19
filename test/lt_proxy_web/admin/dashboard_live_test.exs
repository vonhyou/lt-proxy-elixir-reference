defmodule LtProxyWeb.Admin.DashboardLiveTest do
  use LtProxyWeb.AdminCase, async: false

  import LtProxy.UpstreamStub

  alias LtProxy.{Admin, ApiKeys}

  setup %{conn: conn} do
    Admin.clear_cache()
    Req.Test.set_req_test_to_shared()

    stub()

    {:ok, conn: authorize(conn)}
  end

  test "renders stats", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    status = Admin.status()

    assert has_element?(view, "#stat-provider", status.provider)
    assert has_element?(view, "#stat-slots", "0 / #{status.max_concurrency}")
    assert has_element?(view, "#stat-cache", "0")
    assert has_element?(view, "#stat-requests")
    assert has_element?(view, "#stat-uptime", ~r/\d+(s|m|h|d)/)
    assert has_element?(view, "#stat-model", status.model)
    assert has_element?(view, "#stat-prompt", to_string(status.prompt_version))
    assert has_element?(view, ".menu a.menu-active", "Dashboard")
    assert has_element?(view, "#reconnecting.hidden")
  end

  test "refresh tick re-reads status", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#stat-cache", "0")

    {:ok, _} = Admin.test_translate("Bonjour", "en")
    send(view.pid, :refresh)

    assert has_element?(view, "#stat-cache", "1")
  end

  test "clear cache empties the cache and flashes", %{conn: conn} do
    {:ok, _} = Admin.test_translate("Bonjour", "en")
    {:ok, view, _html} = live(conn, "/")
    assert has_element?(view, "#stat-cache", "1")
    assert has_element?(view, "#clear-cache[data-confirm]")

    html = view |> element("#clear-cache") |> render_click()

    assert html =~ "Cache cleared"
    assert has_element?(view, "#stat-cache", "0")
    assert Admin.status().cache_entries == 0
  end

  describe "test translation" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      %{view: view}
    end

    test "shows the translation with a loading state", %{view: view} do
      test = self()

      stub(fn ->
        send(test, {:waiting, self()})
        receive do: (:go -> ~s({"source": "fr", "translation": "Hello"}))
      end)

      view |> form("#test-form", test: %{text: "Bonjour", target: "en"}) |> render_submit()
      assert_receive {:waiting, pid}
      assert has_element?(view, "#test-form button[disabled] .loading")

      send(pid, :go)
      html = render_async(view)
      assert has_element?(view, "#result-text", "Hello")
      assert html =~ "Detected fr"
      assert html =~ ~r/\d+ ms/
      refute has_element?(view, "#test-form button[disabled]")
      assert has_element?(view, "#stat-cache", "1")
    end

    test "result text renders escaped", %{view: view} do
      stub(fn -> ~s|{"source": "fr", "translation": "<script>alert(1)</script>"}| end)
      view |> form("#test-form", test: %{text: "Salut", target: "en"}) |> render_submit()
      html = render_async(view)
      assert html =~ "&lt;script&gt;"
      refute html =~ "<script>alert"
    end

    test "errors render a readable message", %{view: view} do
      view |> form("#test-form", test: %{text: "Bonjour", target: "english"}) |> render_submit()
      render_async(view)
      assert has_element?(view, "#result-error", "language code")
    end
  end

  test "shows an empty API keys state", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#keys-empty", "No API keys yet")
    refute has_element?(view, "#keys")
  end

  describe "with API keys" do
    setup do
      key = String.duplicate("a", 20) <> "wxyz"
      System.put_env("LTP_API_KEYS", "alice:#{key},bob:" <> String.duplicate("b", 24))
      ApiKeys.load!()

      on_exit(fn ->
        System.delete_env("LTP_API_KEYS")
        ApiKeys.load!()
      end)

      %{key: key}
    end

    test "lists keys with masked value, count and last use", %{conn: conn, key: key} do
      ApiKeys.record_use("alice")
      ApiKeys.record_use("alice")
      {:ok, view, html} = live(conn, "/")

      assert has_element?(view, "#key-alice", "alice")
      assert has_element?(view, "#key-alice", "…wxyz")
      assert has_element?(view, "#key-alice td", "2")
      assert has_element?(view, "#key-alice", ~r/\d{4}-\d\d-\d\d \d\d:\d\d UTC/)
      assert has_element?(view, "#key-bob", "never")
      refute html =~ key
      refute has_element?(view, "#keys-empty")
    end
  end
end
