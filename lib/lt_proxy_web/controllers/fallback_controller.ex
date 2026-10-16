defmodule LtProxyWeb.FallbackController do
  use LtProxyWeb, :controller

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

  def call(conn, {:error, reason}) do
    {status, message} = Map.get(@errors, reason, {502, "Translation failed"})

    conn
    |> put_status(status)
    |> json(%{error: message})
  end
end
