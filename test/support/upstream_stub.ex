defmodule LtProxy.UpstreamStub do
  @moduledoc false

  @doc "Stubs the model to reply with `content` (a string, or a function returning one)."
  def stub(content \\ ~s({"source": "fr", "translation": "Hello"})) do
    Req.Test.stub(LtProxy.Upstream, &reply(&1, content))
  end

  @doc "Sends an OpenRouter chat completion response."
  def reply(conn, content, usage \\ %{})
  def reply(conn, content, usage) when is_function(content, 0), do: reply(conn, content.(), usage)

  def reply(conn, content, usage) do
    Req.Test.json(conn, %{
      "choices" => [%{"message" => %{"content" => content}}],
      "usage" => usage
    })
  end
end
