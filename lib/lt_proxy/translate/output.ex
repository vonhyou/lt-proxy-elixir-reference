defmodule LtProxy.Translate.Output do
  @moduledoc "Parses the model's JSON reply."

  alias LtProxy.Translate.Lang

  @type t :: %{lang: String.t() | nil, text: String.t()}

  @spec parse(String.t()) :: {:ok, t()} | {:error, :invalid_output}
  def parse(raw) when is_binary(raw) do
    case raw |> strip_fences() |> JSON.decode() do
      {:ok, %{"translation" => text} = reply} when is_binary(text) and text != "" ->
        {:ok, %{text: text, lang: lang(reply["source"])}}

      _ ->
        {:error, :invalid_output}
    end
  end

  defp strip_fences(raw) do
    raw
    |> String.trim()
    |> String.replace(~r/\A```(?:json)?\s*|\s*```\z/, "")
  end

  defp lang(code) do
    case Lang.normalize(code) do
      {:ok, code} -> code
      {:error, _} -> nil
    end
  end
end
