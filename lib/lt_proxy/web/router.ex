defmodule LtProxy.Web.Router do
  @moduledoc "LibreTranslate-compatible HTTP API."

  use Plug.Router
  use Plug.ErrorHandler

  alias LtProxy.{Config, RateLimit, Translator}
  alias LtProxy.Translate.{Lang, Request}

  @errors %{
    missing_text: {400, "Invalid request: missing q parameter"},
    missing_target: {400, "Invalid request: missing target parameter"},
    invalid_lang: {400, "Invalid request: unsupported language code"},
    invalid_format: {400, "Invalid request: format must be text or html"},
    too_long: {400, "Invalid request: text is too long"},
    forbidden: {403, "Invalid API key"},
    rate_limited: {429, "Slowdown: too many requests"},
    overloaded: {503, "Translation service is busy, try again later"}
  }

  plug(:match)
  plug(:parse_body)
  plug(:dispatch)

  get "/health" do
    send_resp(conn, 200, "ok")
  end

  get "/languages" do
    json(conn, 200, Lang.supported())
  end

  post "/translate" do
    with :ok <- authorize(conn.params["api_key"]),
         :ok <- RateLimit.check(),
         {:ok, request} <- Request.from_params(conn.params),
         {:ok, result} <- Translator.translate(request) do
      json(conn, 200, %{
        translatedText: result.text,
        detectedLanguage: %{language: result.lang || "und", confidence: 90.0}
      })
    else
      {:error, reason} ->
        {status, message} = Map.get(@errors, reason, {502, "Translation failed"})
        json(conn, status, %{error: message})
    end
  end

  match _ do
    json(conn, 404, %{error: "Not found"})
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, _error) do
    json(conn, conn.status, %{error: Plug.Conn.Status.reason_phrase(conn.status)})
  end

  # Plug.Parsers options are fixed at compile time unless built per request.
  defp parse_body(conn, _opts) do
    opts =
      Plug.Parsers.init(
        parsers: [:urlencoded, :json],
        pass: ["*/*"],
        json_decoder: JSON,
        length: Config.fetch!(:max_body_bytes)
      )

    Plug.Parsers.call(conn, opts)
  end

  defp authorize(given) do
    case Config.fetch!(:api_key) do
      nil ->
        :ok

      expected when is_binary(given) ->
        if Plug.Crypto.secure_compare(given, expected), do: :ok, else: {:error, :forbidden}

      _expected ->
        {:error, :forbidden}
    end
  end

  defp json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, JSON.encode!(body))
  end
end
