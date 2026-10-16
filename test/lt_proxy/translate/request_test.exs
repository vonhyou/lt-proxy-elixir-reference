defmodule LtProxy.Translate.RequestTest do
  use ExUnit.Case, async: true

  alias LtProxy.Translate.Request

  test "builds a request with defaults" do
    assert {:ok, %Request{text: "Bonjour", source: "auto", target: "en", format: :text}} =
             Request.from_params(%{"q" => "Bonjour", "target" => "en"})
  end

  test "normalizes language codes and format" do
    assert {:ok, %Request{source: "ja", target: "fr", format: :html}} =
             Request.from_params(%{
               "q" => "<p>x</p>",
               "source" => "ja-JP",
               "target" => "FR",
               "format" => "html"
             })
  end

  test "rejects invalid params" do
    assert {:error, :missing_text} = Request.from_params(%{"target" => "en"})
    assert {:error, :missing_text} = Request.from_params(%{"q" => "  \n", "target" => "en"})
    assert {:error, :missing_text} = Request.from_params(%{"q" => ["a"], "target" => "en"})
    assert {:error, :missing_text} = Request.from_params(%{"q" => <<0xFF>>, "target" => "en"})
    assert {:error, :missing_target} = Request.from_params(%{"q" => "a"})
    assert {:error, :invalid_lang} = Request.from_params(%{"q" => "a", "target" => "english"})

    assert {:error, :invalid_lang} =
             Request.from_params(%{"q" => "a", "source" => "x", "target" => "en"})

    assert {:error, :invalid_format} =
             Request.from_params(%{"q" => "a", "target" => "en", "format" => "md"})

    assert {:error, :too_long} =
             Request.from_params(%{"q" => String.duplicate("a", 20_001), "target" => "en"})
  end
end
