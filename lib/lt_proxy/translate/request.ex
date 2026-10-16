defmodule LtProxy.Translate.Request do
  @moduledoc "A validated LibreTranslate `/translate` request."

  alias LtProxy.Translate.Lang

  @max_text_bytes 20_000

  @enforce_keys [:text, :source, :target]
  defstruct [:text, :source, :target, format: :text]

  @type t :: %__MODULE__{
          text: String.t(),
          source: String.t(),
          target: String.t(),
          format: :text | :html
        }

  @type error :: :missing_text | :missing_target | :invalid_lang | :invalid_format | :too_long

  @spec from_params(map()) :: {:ok, t()} | {:error, error()}
  def from_params(params) when is_map(params) do
    with {:ok, text} <- text(params["q"]),
         {:ok, source} <- source(params["source"]),
         {:ok, target} <- target(params["target"]),
         {:ok, format} <- format(params["format"]) do
      {:ok, %__MODULE__{text: text, source: source, target: target, format: format}}
    end
  end

  defp text(q) when is_binary(q) do
    cond do
      byte_size(q) > @max_text_bytes -> {:error, :too_long}
      not String.valid?(q) or String.trim(q) == "" -> {:error, :missing_text}
      true -> {:ok, q}
    end
  end

  defp text(_q), do: {:error, :missing_text}

  defp source(source) when source in [nil, "", "auto"], do: {:ok, "auto"}
  defp source(source), do: Lang.normalize(source)

  defp target(target) when target in [nil, ""], do: {:error, :missing_target}
  defp target(target), do: Lang.normalize(target)

  defp format(format) when format in [nil, "", "text"], do: {:ok, :text}
  defp format("html"), do: {:ok, :html}
  defp format(_format), do: {:error, :invalid_format}
end
