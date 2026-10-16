defmodule LtProxy.Web.RouterTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias LtProxy.{Cache, Upstream}
  alias LtProxy.Web.Router

  setup do
    Cache.clear()
    Req.Test.set_req_test_to_shared()
    :ok
  end

  test "GET /health" do
    assert %{status: 200, resp_body: "ok"} = call(conn(:get, "/health"))
  end

  test "GET /languages" do
    conn = call(conn(:get, "/languages"))
    assert conn.status == 200
    assert [%{"code" => _, "name" => _, "targets" => [_ | _]} | _] = JSON.decode!(conn.resp_body)
  end

  test "POST /translate with a JSON body" do
    stub_reply(~s({"source": "fr", "translation": "Hello"}))

    conn =
      :post
      |> conn(
        "/translate",
        JSON.encode!(%{q: "Bonjour", source: "auto", target: "en", api_key: "test-key"})
      )
      |> put_req_header("content-type", "application/json")
      |> call()

    assert conn.status == 200
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")

    assert %{
             "translatedText" => "Hello",
             "detectedLanguage" => %{"language" => "fr", "confidence" => _}
           } =
             JSON.decode!(conn.resp_body)
  end

  test "POST /translate with a form body" do
    stub_reply(~s({"source": "fr", "translation": "Hello"}))

    conn =
      :post
      |> conn("/translate", "q=Bonjour&target=en&api_key=test-key")
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> call()

    assert %{"translatedText" => "Hello"} = json_body(conn, 200)
  end

  test "falls back to an undetermined language" do
    stub_reply(~s({"source": "??", "translation": "Hello"}))

    assert %{"detectedLanguage" => %{"language" => "und"}} =
             json_body(translate(%{q: "Bonjour", target: "en"}), 200)
  end

  test "rejects a wrong or missing api key" do
    assert %{"error" => _} = json_body(translate(%{q: "a", target: "en", api_key: "nope"}), 403)
    assert %{"error" => _} = json_body(translate(%{q: "a", target: "en", api_key: nil}), 403)
  end

  test "rejects missing text" do
    assert %{"error" => "Invalid request: missing q parameter"} =
             json_body(translate(%{target: "en"}), 400)
  end

  test "maps upstream failures to 502" do
    Req.Test.stub(Upstream, &send_resp(&1, 500, ""))

    assert %{"error" => _} = json_body(translate(%{q: "Bonjour", target: "en"}), 502)
  end

  test "rejects oversized bodies without calling upstream" do
    Req.Test.stub(Upstream, fn _conn -> flunk("upstream called") end)

    assert_raise Plug.Parsers.RequestTooLargeError, fn ->
      translate(%{q: String.duplicate("a", 200_000), target: "en"})
    end

    assert_received {_ref, {413, _headers, body}}
    assert %{"error" => "Request Entity Too Large"} = JSON.decode!(body)
  end

  test "rejects malformed JSON" do
    assert_raise Plug.Parsers.ParseError, fn ->
      :post
      |> conn("/translate", "{")
      |> put_req_header("content-type", "application/json")
      |> call()
    end

    assert_received {_ref, {400, _headers, body}}
    assert %{"error" => "Bad Request"} = JSON.decode!(body)
  end

  test "unknown routes return 404" do
    assert %{"error" => "Not found"} = json_body(call(conn(:get, "/nope")), 404)
  end

  defp translate(params) do
    params = Map.put_new(params, :api_key, "test-key")

    :post
    |> conn("/translate", JSON.encode!(params))
    |> put_req_header("content-type", "application/json")
    |> call()
  end

  defp call(conn), do: Router.call(conn, Router.init([]))

  defp json_body(conn, status) do
    assert conn.status == status
    JSON.decode!(conn.resp_body)
  end

  defp stub_reply(content) do
    Req.Test.stub(
      Upstream,
      &Req.Test.json(&1, %{"choices" => [%{"message" => %{"content" => content}}]})
    )
  end
end
