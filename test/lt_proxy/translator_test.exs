defmodule LtProxy.TranslatorTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  import LtProxy.UpstreamStub

  alias LtProxy.{Cache, Slots, Translator, Upstream}
  alias LtProxy.Translate.Request

  @request %Request{text: "Bonjour le monde", source: "auto", target: "en"}

  setup do
    Cache.clear()
    Req.Test.set_req_test_to_shared()
    :ok
  end

  test "translates and detects the source language" do
    stub_reply(~s({"source": "fr", "translation": "Hello world"}))
    assert {:ok, %{text: "Hello world", lang: "fr"}} = Translator.translate(@request)
  end

  test "prefers an explicit source over the detected one" do
    stub_reply(~s({"source": "it", "translation": "Hello world"}))
    assert {:ok, %{lang: "fr"}} = Translator.translate(%{@request | source: "fr"})
  end

  test "skips upstream when source equals target" do
    assert {:ok, %{text: "Hi", lang: "en"}} =
             Translator.translate(%{@request | text: "Hi", source: "en"})
  end

  test "rejects prose output" do
    stub_reply("Hello world")
    assert {:error, :invalid_output} = Translator.translate(@request)
  end

  test "retries an empty reply cut off by max_tokens with double the budget" do
    test = self()

    Req.Test.stub(Upstream, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      max_tokens = JSON.decode!(body)["max_tokens"]
      send(test, {:max_tokens, max_tokens})

      if max_tokens < 4096,
        do: empty_reply(conn, "length"),
        else: reply(conn, ~s({"source": "fr", "translation": "Hello world"}))
    end)

    log =
      capture_log(fn ->
        assert {:ok, %{text: "Hello world"}} = Translator.translate(@request)
      end)

    assert_received {:max_tokens, first}
    assert_received {:max_tokens, second}
    assert second == 2 * first
    assert log =~ "finish_reason=length"
  end

  test "logs the finish reason when the reply stays empty" do
    Req.Test.stub(Upstream, &empty_reply(&1, "length"))

    log =
      capture_log(fn ->
        assert {:error, {:empty_reply, "length"}} = Translator.translate(@request)
      end)

    assert log =~ ~s(translation failed: {:empty_reply, "length"})
    refute log =~ "Bonjour"
  end

  test "does not retry other empty replies" do
    test = self()

    Req.Test.stub(Upstream, fn conn ->
      send(test, :called)
      empty_reply(conn, "stop")
    end)

    capture_log(fn ->
      assert {:error, {:empty_reply, "stop"}} = Translator.translate(@request)
    end)

    assert_received :called
    refute_received :called
  end

  test "logs usage without the note text" do
    stub_reply(~s({"source": "fr", "translation": "Hello world"}), %{"total_tokens" => 42})

    log = capture_log(fn -> Translator.translate(@request) end)
    assert log =~ "tokens=42"
    refute log =~ "Bonjour"
  end

  test "caches successful translations" do
    stub_counting(~s({"source": "fr", "translation": "Hello world"}))

    assert {:ok, _} = Translator.translate(@request)
    assert_received :called

    {elapsed, {:ok, %{text: "Hello world"}}} = :timer.tc(fn -> Translator.translate(@request) end)
    refute_received :called
    assert elapsed < 5_000
  end

  test "deduplicates concurrent identical requests" do
    test = self()

    Req.Test.stub(Upstream, fn conn ->
      send(test, {:called, self()})
      receive do: (:release -> :ok)
      reply(conn, ~s({"source": "fr", "translation": "Hello world"}))
    end)

    tasks = for _ <- 1..5, do: Task.async(fn -> Translator.translate(@request) end)

    assert_receive {:called, upstream}, 1_000
    Process.sleep(50)
    send(upstream, :release)

    assert Enum.uniq(Task.await_many(tasks)) == [{:ok, %{text: "Hello world", lang: "fr"}}]
    refute_received {:called, _}
  end

  test "does not cache errors" do
    test = self()

    Req.Test.stub(Upstream, fn conn ->
      send(test, :called)
      Plug.Conn.send_resp(conn, 500, "")
    end)

    assert {:error, {:upstream_status, 500}} = Translator.translate(@request)
    assert {:error, {:upstream_status, 500}} = Translator.translate(@request)

    assert_received :called
    assert_received :called
  end

  test "does not cache overload rejections" do
    Slots.init(1)
    on_exit(fn -> Slots.init(LtProxy.Config.fetch!(:max_concurrency)) end)

    test = self()

    Req.Test.stub(Upstream, fn conn ->
      send(test, {:called, self()})
      receive do: (:release -> :ok)
      reply(conn, ~s({"source": "fr", "translation": "Hello"}))
    end)

    blocking = Task.async(fn -> Translator.translate(%{@request | text: "Salut"}) end)
    assert_receive {:called, upstream}

    assert {:error, :overloaded} = Translator.translate(@request)

    send(upstream, :release)
    Task.await(blocking)

    stub_reply(~s({"source": "fr", "translation": "Hello world"}))
    assert {:ok, %{text: "Hello world"}} = Translator.translate(@request)
  end

  test "frees the slot when the upstream request crashes" do
    Req.Test.stub(Upstream, fn _conn -> raise "boom" end)

    assert {:error, {:transport, :crashed}} = Translator.translate(@request)
    assert Slots.in_use() == 0
  end

  defp stub_reply(content, usage \\ %{}), do: Req.Test.stub(Upstream, &reply(&1, content, usage))

  defp stub_counting(content) do
    test = self()

    Req.Test.stub(Upstream, fn conn ->
      send(test, :called)
      reply(conn, content)
    end)
  end
end
