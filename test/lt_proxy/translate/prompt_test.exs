defmodule LtProxy.Translate.PromptTest do
  use ExUnit.Case, async: true

  alias LtProxy.Translate.{Prompt, Request}

  @text "Salut @bob@example.com :blobcat:\nhttps://example.com"

  test "builds a system and a user message" do
    request = %Request{text: @text, source: "auto", target: "ja"}

    assert [%{role: "system", content: system}, %{role: "user", content: @text}] =
             Prompt.build(request)

    assert system =~ "Japanese (ja)"
    refute system =~ "from "
    refute system =~ "HTML"
  end

  test "sizes max_tokens by input, with room for reasoning and a cap" do
    assert %{max_tokens: 2058} =
             Prompt.params(%Request{text: "hello", source: "auto", target: "en"})

    assert %{max_tokens: 16_384} =
             Prompt.params(%Request{
               text: String.duplicate("a", 32_000),
               source: "auto",
               target: "en"
             })
  end

  test "document mode uses the document prompt" do
    request = %Request{text: @text, source: "auto", target: "en", mode: :document}
    [%{content: system}, _user] = Prompt.build(request)

    assert system =~ "document"
    assert system =~ "Markdown"
    refute system =~ "fediverse"
  end

  test "mentions an explicit source and html format" do
    request = %Request{text: @text, source: "fr", target: "en", format: :html}
    [%{content: system}, _user] = Prompt.build(request)

    assert system =~ "from French (fr)"
    assert system =~ "HTML"
  end
end
