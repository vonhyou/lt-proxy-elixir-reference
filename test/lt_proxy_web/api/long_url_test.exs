defmodule LtProxyWeb.Api.LongUrlTest do
  use LtProxyWeb.ConnCase, async: false

  import LtProxy.UpstreamStub

  setup do
    LtProxy.Cache.clear()
    Req.Test.set_req_test_to_shared()

    stub(~s({"source": "fr", "translation": "ok"}))

    query = URI.encode_query(%{q: String.duplicate("é", 3_500), target: "en", api_key: api_key()})
    assert byte_size(query) > 20_000
    %{path: "/translate?" <> query}
  end

  test "accepts a 20 KB query string with the endpoint's line limit", %{path: path} do
    http_1_options = LtProxyWeb.ApiEndpoint.config(:http)[:http_1_options]

    assert %{status: 200, body: %{"translatedText" => "ok"}} =
             post_via_listener(path, http_1_options)
  end

  test "Bandit's default line limit would reject it", %{path: path} do
    assert %{status: 414} = post_via_listener(path, [])
  end

  defp post_via_listener(path, http_1_options) do
    pid =
      start_supervised!(
        {Bandit,
         plug: LtProxyWeb.ApiEndpoint, ip: :loopback, port: 0, http_1_options: http_1_options}
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)
    Req.post!("http://127.0.0.1:#{port}#{path}", retry: false)
  end
end
