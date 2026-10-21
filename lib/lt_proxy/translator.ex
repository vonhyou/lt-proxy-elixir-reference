defmodule LtProxy.Translator do
  @moduledoc "Translates a request: cache, then concurrency slot, then upstream model."

  require Logger

  alias LtProxy.{Cache, Slots, Upstream}
  alias LtProxy.Translate.{Output, Prompt, Request}

  @type result :: %{text: String.t(), lang: String.t() | nil}

  # Finish reasons for a reply cut off by max_tokens (OpenAI-style, Anthropic).
  @truncated ["length", "max_tokens"]

  @spec translate(Request.t()) :: {:ok, result()} | {:error, term()}
  def translate(%Request{source: lang, target: lang, text: text}),
    do: {:ok, %{text: text, lang: lang}}

  def translate(%Request{} = request) do
    Cache.fetch(Cache.key(request), fn -> Slots.run(fn -> call(request) end) end)
  end

  defp call(request) do
    started = System.monotonic_time(:millisecond)

    with {:ok, content, usage} <- chat(request),
         {:ok, output} <- Output.parse(content) do
      log_usage(request, usage, started)
      {:ok, %{text: output.text, lang: detected(request.source, output.lang)}}
    else
      {:error, reason} = error ->
        Logger.warning("translation failed: #{inspect(reason)}")
        error
    end
  end

  # An empty reply cut off by max_tokens means reasoning used the budget; retry once with double.
  defp chat(request) do
    messages = Prompt.build(request)
    params = Prompt.params(request)

    with {:error, {:empty_reply, reason}} when reason in @truncated <-
           Upstream.chat(messages, params) do
      Logger.warning("empty reply (finish_reason=#{reason}), retrying with more tokens")
      Upstream.chat(messages, %{params | max_tokens: 2 * params.max_tokens})
    end
  end

  defp detected("auto", lang), do: lang
  defp detected(source, _lang), do: source

  defp log_usage(request, usage, started) do
    usage = usage || %{}
    elapsed = System.monotonic_time(:millisecond) - started

    Logger.info(
      "translated #{request.source}->#{request.target} in #{elapsed}ms " <>
        "tokens=#{usage["total_tokens"]} cost=#{usage["cost"]}"
    )
  end
end
