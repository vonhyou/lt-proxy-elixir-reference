defmodule LtProxy.Translate.RequestTest do
  use ExUnit.Case, async: true

  alias LtProxy.Translate.Request

  test "builds a request with defaults" do
    assert {:ok,
            %Request{text: "Bonjour", source: "auto", target: "en", format: :text, mode: :post}} =
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

  test "parses mode" do
    assert {:ok, %Request{mode: :document}} =
             Request.from_params(%{"q" => "a", "target" => "en", "mode" => "document"})

    assert {:ok, %Request{mode: :post}} =
             Request.from_params(%{"q" => "a", "target" => "en", "mode" => ""})
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

    assert {:error, :invalid_mode} =
             Request.from_params(%{"q" => "a", "target" => "en", "mode" => "book"})

    assert {:ok, _request} =
             Request.from_params(%{"q" => String.duplicate("a", 32_000), "target" => "en"})

    assert {:error, :too_long} =
             Request.from_params(%{"q" => String.duplicate("a", 32_001), "target" => "en"})
  end
end
