defmodule LtProxy.UpstreamTest do
  use ExUnit.Case, async: false

  alias LtProxy.Upstream

  @messages [%{role: "user", content: "Say hi"}]

  test "returns content and usage" do
    Req.Test.stub(Upstream, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"model" => _, "messages" => [_], "provider" => %{"zdr" => true}, "extra" => 1} =
               JSON.decode!(body)

      assert ["Bearer test-openrouter-key"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        "choices" => [%{"message" => %{"content" => "hi"}}],
        "usage" => %{"total_tokens" => 3}
      })
    end)

    assert {:ok, "hi", %{"total_tokens" => 3}} = Upstream.chat(@messages, %{extra: 1})
  end

  test "handles empty replies" do
    Req.Test.stub(Upstream, &Req.Test.json(&1, %{"choices" => []}))
    assert {:error, :empty_reply} = Upstream.chat(@messages)

    Req.Test.stub(
      Upstream,
      &Req.Test.json(&1, %{"choices" => [%{"message" => %{"content" => ""}}]})
    )

    assert {:error, :empty_reply} = Upstream.chat(@messages)
  end

  test "maps error statuses" do
    for status <- [429, 500] do
      Req.Test.stub(Upstream, &Plug.Conn.send_resp(&1, status, "nope"))
      assert {:error, {:upstream_status, ^status}} = Upstream.chat(@messages)
    end
  end

  test "maps transport errors" do
    Req.Test.stub(Upstream, &Req.Test.transport_error(&1, :timeout))
    assert {:error, {:transport, :timeout}} = Upstream.chat(@messages)
  end

  describe "retries and time budget" do
    setup do
      req_options = Application.get_env(:lt_proxy, :req_options)
      on_exit(fn -> Application.put_env(:lt_proxy, :req_options, req_options) end)
    end

    test "does not retry error statuses" do
      Application.put_env(:lt_proxy, :req_options, plug: {Req.Test, Upstream})
      test = self()

      for status <- [429, 500] do
        Req.Test.stub(Upstream, fn conn ->
          send(test, :called)
          Plug.Conn.send_resp(conn, status, "nope")
        end)

        assert {:error, {:upstream_status, ^status}} = Upstream.chat(@messages)
        assert_received :called
        refute_received :called
      end
    end

    test "retries once on a closed connection" do
      test = self()

      port =
        listen(fn socket ->
          send(test, :accepted)
          {:ok, _request} = :gen_tcp.recv(socket, 0)
          :gen_tcp.close(socket)
        end)

      Application.put_env(:lt_proxy, :req_options, base_url: "http://127.0.0.1:#{port}")

      assert {:error, {:transport, :closed}} = Upstream.chat(@messages)
      assert_received :accepted
      assert_received :accepted
      refute_received :accepted
    end

    test "fails within the timeout, without retrying, when upstream never answers" do
      test = self()
      port = listen(fn _socket -> send(test, :accepted) end)
      Application.put_env(:lt_proxy, :req_options, base_url: "http://127.0.0.1:#{port}")
      put_setting(:upstream_timeout_ms, 300)

      {elapsed, result} = :timer.tc(fn -> Upstream.chat(@messages) end, :millisecond)

      assert {:error, {:transport, :timeout}} = result
      assert elapsed <= 300 + 1000
      assert_received :accepted
      refute_received :accepted
    end

    test "enforces the deadline even if the client never times out" do
      Application.put_env(:lt_proxy, :req_options, plug: {Req.Test, Upstream})
      put_setting(:upstream_timeout_ms, 300)
      Req.Test.stub(Upstream, fn conn -> Process.sleep(5_000) && conn end)

      {elapsed, result} = :timer.tc(fn -> Upstream.chat(@messages) end, :millisecond)

      assert {:error, {:transport, :timeout}} = result
      assert elapsed <= 300 + 1000
    end

    test "returns an error when the request crashes" do
      Req.Test.stub(Upstream, fn _conn -> raise "boom" end)
      assert {:error, {:transport, :crashed}} = Upstream.chat(@messages)
    end
  end

  defp listen(handle) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, port} = :inet.port(listener)
    spawn_link(fn -> accept_loop(listener, handle) end)
    port
  end

  defp accept_loop(listener, handle) do
    with {:ok, socket} <- :gen_tcp.accept(listener) do
      handle.(socket)
      accept_loop(listener, handle)
    end
  end

  defp put_setting(key, value) do
    previous = LtProxy.Config.fetch!(key)
    :ok = LtProxy.Settings.update(%{to_string(key) => to_string(value)})

    on_exit(fn ->
      ExUnit.CaptureLog.capture_log(fn ->
        LtProxy.Settings.update(%{to_string(key) => to_string(previous)})
      end)
    end)
  end
end
