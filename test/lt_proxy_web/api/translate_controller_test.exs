defmodule LtProxyWeb.Api.TranslateControllerTest do
  use LtProxyWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  import LtProxy.UpstreamStub

  alias LtProxy.{Cache, RateLimit, Upstream}

  setup do
    Cache.clear()
    Req.Test.set_req_test_to_shared()
    :ok
  end

  test "GET /health", %{conn: conn} do
    assert %{status: 200, resp_body: "ok"} = get(conn, "/health")
  end

  test "GET /languages", %{conn: conn} do
    assert [%{"code" => _, "name" => _, "targets" => [_ | _]} | _] =
             conn |> get("/languages") |> json_response(200)
  end

  test "POST /translate with a JSON body", %{conn: conn} do
    stub(~s({"source": "fr", "translation": "Hello"}))

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(
        "/translate",
        JSON.encode!(%{q: "Bonjour", source: "auto", target: "en", api_key: api_key()})
      )

    assert conn.status == 200
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")

    assert %{
             "translatedText" => "Hello",
             "detectedLanguage" => %{"language" => "fr", "confidence" => _}
           } = JSON.decode!(conn.resp_body)
  end

  test "POST /translate with a form body", %{conn: conn} do
    stub(~s({"source": "fr", "translation": "Hello"}))

    conn =
      conn
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> post("/translate", "q=Bonjour&target=en&api_key=#{api_key()}")

    assert %{"translatedText" => "Hello"} = json_response(conn, 200)
  end

  test "POST /translate with query parameters and an empty body", %{conn: conn} do
    stub(~s({"source": "fr", "translation": "Hello"}))

    conn =
      post(
        conn,
        "/translate?q=Bonjour&source=auto&target=en&api_key=#{api_key()}&format=text&alternatives=3"
      )

    assert %{"translatedText" => "Hello", "detectedLanguage" => %{"language" => "fr"}} =
             json_response(conn, 200)
  end

  test "falls back to an undetermined language", %{conn: conn} do
    stub(~s({"source": "??", "translation": "Hello"}))

    assert %{"detectedLanguage" => %{"language" => "und"}} =
             json_response(translate(conn, %{q: "Bonjour", target: "en"}), 200)
  end

  test "rejects a wrong or missing api key", %{conn: conn} do
    assert %{"error" => _} =
             json_response(translate(conn, %{q: "a", target: "en", api_key: "nope"}), 403)

    assert %{"error" => _} =
             json_response(translate(conn, %{q: "a", target: "en", api_key: nil}), 403)
  end

  test "rejects missing text", %{conn: conn} do
    assert %{"error" => "Invalid request: missing q parameter"} =
             json_response(translate(conn, %{target: "en"}), 400)
  end

  test "maps upstream failures to 502", %{conn: conn} do
    Req.Test.stub(Upstream, &send_resp(&1, 500, ""))

    assert %{"error" => "Translation failed"} =
             json_response(translate(conn, %{q: "Bonjour", target: "en"}), 502)
  end

  test "rejects oversized bodies without calling upstream", %{conn: conn} do
    Req.Test.stub(Upstream, fn _conn -> flunk("upstream called") end)

    assert {413, headers, body} =
             assert_error_sent(413, fn ->
               translate(conn, %{q: String.duplicate("a", 200_000), target: "en"})
             end)

    assert {"content-type", "application/json" <> _} = List.keyfind(headers, "content-type", 0)
    assert %{"error" => "Request Entity Too Large"} = JSON.decode!(body)
  end

  test "rejects malformed JSON", %{conn: conn} do
    assert {400, _headers, body} =
             assert_error_sent(400, fn ->
               conn
               |> put_req_header("content-type", "application/json")
               |> post("/translate", "{")
             end)

    assert %{"error" => "Bad Request"} = JSON.decode!(body)
  end

  test "records usage for the named key", %{conn: conn} do
    stub(~s({"source": "fr", "translation": "Hello"}))

    assert %{"translatedText" => "Hello"} =
             translate(conn, %{q: "Bonjour", target: "en"}) |> json_response(200)

    assert [%{name: "test", requests: 1, last_used_at: %DateTime{}}] = LtProxy.ApiKeys.list()
  end

  test "rate limiting returns 429 JSON", %{conn: conn} do
    stub(~s({"source": "fr", "translation": "Hello"}))
    :ok = LtProxy.Settings.update(%{"rpm" => "1"})
    on_exit(fn -> capture_log(fn -> LtProxy.Settings.update(%{"rpm" => ""}) end) end)

    RateLimit.check()
    conn = translate(conn, %{q: "Bonjour", target: "en"})
    assert %{"error" => "Slowdown: too many requests"} = json_response(conn, 429)
  end

  test "overload returns 503 JSON", %{conn: conn} do
    LtProxy.Slots.init(1)
    on_exit(fn -> LtProxy.Slots.init(LtProxy.Config.fetch!(:max_concurrency)) end)
    test = self()

    Req.Test.stub(Upstream, fn conn ->
      send(test, {:called, self()})
      receive do: (:release -> :ok)
      reply(conn, "{}")
    end)

    blocking = Task.async(fn -> translate(build_conn(), %{q: "Salut", target: "en"}) end)
    assert_receive {:called, upstream}

    conn = translate(conn, %{q: "Bonjour", target: "en"})
    assert %{"error" => "Translation service is busy, try again later"} = json_response(conn, 503)

    send(upstream, :release)
    Task.await(blocking)
  end

  test "unknown routes return 404", %{conn: conn} do
    assert %{"error" => "Not found"} = conn |> get("/nope") |> json_response(404)
  end

  test "does not log note text or the api key", %{conn: conn} do
    stub(~s({"source": "fr", "translation": "Hello"}))
    level = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: level) end)

    log =
      capture_log([level: :debug], fn ->
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/translate?api_key=#{api_key()}",
          JSON.encode!(%{q: "Secret note", target: "en", api_key: api_key()})
        )
        |> json_response(200)
      end)

    assert log =~ "POST /translate"
    refute log =~ "Secret note"
    refute log =~ api_key()
  end

  defp translate(conn, params) do
    params = Map.put_new(params, :api_key, api_key())

    conn
    |> put_req_header("content-type", "application/json")
    |> post("/translate", JSON.encode!(params))
  end
end
