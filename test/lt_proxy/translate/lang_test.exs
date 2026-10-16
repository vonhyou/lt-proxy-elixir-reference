defmodule LtProxy.Translate.LangTest do
  use ExUnit.Case, async: true

  alias LtProxy.Translate.Lang

  doctest Lang

  cases = [
    {"en", {:ok, "en"}},
    {"EN", {:ok, "en"}},
    {"ja-JP", {:ok, "ja"}},
    {"zh_Hant", {:ok, "zh"}},
    {"PT_br", {:ok, "pt"}},
    {"", {:error, :invalid_lang}},
    {"e", {:error, :invalid_lang}},
    {"english", {:error, :invalid_lang}},
    {"12", {:error, :invalid_lang}},
    {"en-", {:error, :invalid_lang}},
    {nil, {:error, :invalid_lang}}
  ]

  for {input, expected} <- cases do
    test "normalize(#{inspect(input)})" do
      assert Lang.normalize(unquote(input)) == unquote(expected)
    end
  end

  test "supported/0 lists every code as a target" do
    languages = Lang.supported()
    codes = Enum.map(languages, & &1.code)

    assert %{code: "fr", name: "French"} = Enum.find(languages, &(&1.code == "fr"))
    assert Enum.all?(languages, &(&1.targets == codes))
  end
end
