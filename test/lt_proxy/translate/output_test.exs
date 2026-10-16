defmodule LtProxy.Translate.OutputTest do
  use ExUnit.Case, async: true

  alias LtProxy.Translate.Output

  test "parses valid replies" do
    assert {:ok, %{lang: "fr", text: "Hello"}} =
             Output.parse(~s({"source": "fr", "translation": "Hello"}))

    assert {:ok, %{lang: "fr", text: "Hello"}} =
             Output.parse(~s(```json\n{"source": "fr", "translation": "Hello"}\n```))

    assert {:ok, %{lang: "fr", text: "Hi"}} =
             Output.parse(~s({"source": "fr-FR", "translation": "Hi", "note": 1}))

    assert {:ok, %{lang: nil, text: "Hi"}} = Output.parse(~s({"translation": "Hi"}))
  end

  test "rejects invalid replies" do
    for raw <- [
          "Hello there",
          "",
          ~s({"translation": 5}),
          ~s({"source": "fr", "translation": ""}),
          ~s({"source": "fr", "translation": "Hel),
          ~s({"source": "fr", "translation": "a"}\n\n{"source": "fr", "translation": "b"})
        ] do
      assert {:error, :invalid_output} = Output.parse(raw)
    end
  end
end
