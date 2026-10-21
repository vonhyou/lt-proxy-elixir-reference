defmodule LtProxy.ProviderTest do
  use ExUnit.Case, async: false

  alias LtProxy.Provider
  alias LtProxy.Provider.{Anthropic, OpenAI, OpenRouter}
  alias LtProxy.Upstream

  @messages [%{role: "system", content: "Translate"}, %{role: "user", content: "Bonjour"}]
  @chat %{model: "m", messages: @messages, params: %{max_tokens: 50}, zdr: true}

  test "resolves names" do
    assert Provider.fetch!("anthropic") == Anthropic
    assert Provider.name(OpenRouter) == "openrouter"

    assert_raise RuntimeError, ~r/unknown provider "foo".*anthropic/, fn ->
      Provider.fetch!("foo")
    end
  end

  test "OpenAI builds chat completions and parses choices" do
    assert [url: "/chat/completions", json: json] = OpenAI.chat_request(@chat)
    assert json == %{model: "m", messages: @messages, max_tokens: 50}

    assert {:ok, "Hi", %{"total_tokens" => 3}} =
             OpenAI.parse_chat(%{
               "choices" => [%{"message" => %{"content" => "Hi"}}],
               "usage" => %{"total_tokens" => 3}
             })

    assert {:error, {:empty_reply, nil}} = OpenAI.parse_chat(%{"choices" => []})

    assert {:error, {:empty_reply, "length"}} =
             OpenAI.parse_chat(%{
               "choices" => [%{"message" => %{"content" => nil}, "finish_reason" => "length"}]
             })

    assert OpenAI.parse_models(%{"data" => [%{"id" => "b"}, %{"id" => "a"}, %{}]}) == ["a", "b"]
    assert OpenAI.parse_models(%{}) == []
  end

  test "OpenRouter adds the zdr routing flag and turns reasoning off" do
    assert [
             url: "/chat/completions",
             json: %{provider: %{zdr: true}, reasoning: %{effort: "none"}}
           ] =
             OpenRouter.chat_request(@chat)

    assert [url: _, json: %{reasoning: %{effort: "low"}}] =
             OpenRouter.chat_request(Map.put(@chat, :reasoning, %{effort: "low"}))
  end

  test "OpenRouter picks the lowest effort for models with mandatory reasoning" do
    models = %{
      "data" => [
        %{
          "id" => "a",
          "reasoning" => %{"mandatory" => true, "supported_efforts" => ["high", "low"]}
        },
        %{"id" => "b", "reasoning" => %{"mandatory" => true}},
        %{"id" => "c", "reasoning" => %{"mandatory" => false}},
        %{"id" => "d"}
      ]
    }

    assert OpenRouter.mandatory_reasoning(models, "a") == %{effort: "low"}
    assert OpenRouter.mandatory_reasoning(models, "b") == %{effort: "low"}
    assert OpenRouter.mandatory_reasoning(models, "c") == nil
    assert OpenRouter.mandatory_reasoning(models, "d") == nil
    assert OpenRouter.mandatory_reasoning(models, "missing") == nil
    assert OpenRouter.mandatory_reasoning(%{}, "a") == nil
  end

  test "Anthropic moves the system prompt and sums usage" do
    assert [url: "/messages", json: json] = Anthropic.chat_request(@chat)

    assert json == %{
             model: "m",
             system: "Translate",
             messages: [%{role: "user", content: "Bonjour"}],
             max_tokens: 50
           }

    assert %{max_tokens: 1024} =
             Keyword.fetch!(Anthropic.chat_request(%{@chat | params: %{}}), :json)

    assert {:ok, "Hi there", %{"total_tokens" => 7}} =
             Anthropic.parse_chat(%{
               "content" => [
                 %{"type" => "text", "text" => "Hi "},
                 %{"type" => "text", "text" => "there"}
               ],
               "usage" => %{"input_tokens" => 5, "output_tokens" => 2}
             })

    assert {:error, {:empty_reply, "max_tokens"}} =
             Anthropic.parse_chat(%{"content" => [], "stop_reason" => "max_tokens"})

    assert {:error, {:empty_reply, nil}} = Anthropic.parse_chat(%{"error" => %{}})
  end

  describe "through Upstream" do
    setup do
      previous = Application.fetch_env!(:lt_proxy, :provider)
      Application.put_env(:lt_proxy, :provider, Anthropic)
      on_exit(fn -> Application.put_env(:lt_proxy, :provider, previous) end)
    end

    test "sends Anthropic headers and parses its reply" do
      Req.Test.stub(Upstream, fn conn ->
        assert ["test-provider-key"] = Plug.Conn.get_req_header(conn, "x-api-key")
        assert ["2023-06-01"] = Plug.Conn.get_req_header(conn, "anthropic-version")
        assert conn.request_path =~ "/messages"
        Req.Test.json(conn, %{"content" => [%{"type" => "text", "text" => "hi"}]})
      end)

      assert {:ok, "hi", nil} = Upstream.chat(@messages)
    end

    test "lists models" do
      Req.Test.stub(Upstream, fn conn ->
        assert conn.request_path =~ "/models"
        Req.Test.json(conn, %{"data" => [%{"id" => "claude-x"}]})
      end)

      assert {:ok, ["claude-x"]} = Upstream.models()

      Req.Test.stub(Upstream, &Plug.Conn.send_resp(&1, 401, "{}"))
      assert {:error, {:upstream_status, 401}} = Upstream.models()
    end
  end
end
