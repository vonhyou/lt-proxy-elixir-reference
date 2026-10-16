defmodule LtProxy.Translate.Lang do
  @moduledoc "Language code normalization and the advertised language list."

  @names %{
    "ar" => "Arabic",
    "bg" => "Bulgarian",
    "ca" => "Catalan",
    "cs" => "Czech",
    "da" => "Danish",
    "de" => "German",
    "el" => "Greek",
    "en" => "English",
    "eo" => "Esperanto",
    "es" => "Spanish",
    "et" => "Estonian",
    "eu" => "Basque",
    "fa" => "Persian",
    "fi" => "Finnish",
    "fr" => "French",
    "ga" => "Irish",
    "gl" => "Galician",
    "he" => "Hebrew",
    "hi" => "Hindi",
    "hu" => "Hungarian",
    "id" => "Indonesian",
    "it" => "Italian",
    "ja" => "Japanese",
    "ko" => "Korean",
    "lt" => "Lithuanian",
    "lv" => "Latvian",
    "nb" => "Norwegian Bokmål",
    "nl" => "Dutch",
    "pl" => "Polish",
    "pt" => "Portuguese",
    "ro" => "Romanian",
    "ru" => "Russian",
    "sk" => "Slovak",
    "sl" => "Slovenian",
    "sv" => "Swedish",
    "th" => "Thai",
    "tr" => "Turkish",
    "uk" => "Ukrainian",
    "vi" => "Vietnamese",
    "zh" => "Chinese (Simplified)",
    "zt" => "Chinese (Traditional)"
  }

  @doc """
  Reduces a language tag to its lowercase primary subtag.

      iex> LtProxy.Translate.Lang.normalize("ja-JP")
      {:ok, "ja"}

      iex> LtProxy.Translate.Lang.normalize("english")
      {:error, :invalid_lang}
  """
  @spec normalize(String.t()) :: {:ok, String.t()} | {:error, :invalid_lang}
  def normalize(code) when is_binary(code) do
    case Regex.run(~r/\A([a-z]{2,3})(?:[-_][a-z0-9]{1,8})*\z/i, code, capture: :all_but_first) do
      [primary] -> {:ok, String.downcase(primary)}
      nil -> {:error, :invalid_lang}
    end
  end

  def normalize(_code), do: {:error, :invalid_lang}

  @doc """
  English display name for a code, falling back to the code itself.

      iex> LtProxy.Translate.Lang.name("fr")
      "French"
  """
  @spec name(String.t()) :: String.t()
  def name(code), do: Map.get(@names, code, code)

  @doc "Languages in the shape of LibreTranslate's `GET /languages`."
  @spec supported() :: [%{code: String.t(), name: String.t(), targets: [String.t()]}]
  def supported do
    codes = @names |> Map.keys() |> Enum.sort()
    for code <- codes, do: %{code: code, name: @names[code], targets: codes}
  end
end
