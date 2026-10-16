defmodule LtProxy.UpstreamTest do
  use ExUnit.Case, async: true

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
end
