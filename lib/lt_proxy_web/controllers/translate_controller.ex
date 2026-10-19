defmodule LtProxyWeb.TranslateController do
  use LtProxyWeb, :controller

  require Logger

  alias LtProxy.{ApiKeys, RateLimit, Translator}
  alias LtProxy.Translate.{Lang, Request}

  action_fallback LtProxyWeb.FallbackController

  def health(conn, _params), do: send_resp(conn, 200, "ok")

  def languages(conn, _params), do: json(conn, Lang.supported())

  def translate(conn, params) do
    with {:ok, key} <- authenticate(params["api_key"]),
         :ok <- RateLimit.check(key),
         {:ok, request} <- Request.from_params(params),
         {:ok, result} <- Translator.translate(request) do
      json(conn, %{
        translatedText: result.text,
        detectedLanguage: %{language: result.lang || "und", confidence: 90.0}
      })
    end
  end

  defp authenticate(given) do
    case ApiKeys.authenticate(given) do
      {:ok, name} ->
        Logger.metadata(key: name)
        ApiKeys.record_use(name)
        {:ok, name}

      :error ->
        {:error, :forbidden}
    end
  end
end
