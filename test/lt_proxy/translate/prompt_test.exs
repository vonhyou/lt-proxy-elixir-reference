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

  test "bounds max_tokens by input size" do
    assert %{max_tokens: 261} =
             Prompt.params(%Request{text: "hello", source: "auto", target: "en"})
  end

  test "mentions an explicit source and html format" do
    request = %Request{text: @text, source: "fr", target: "en", format: :html}
    [%{content: system}, _user] = Prompt.build(request)

    assert system =~ "from French (fr)"
    assert system =~ "HTML"
  end
end
