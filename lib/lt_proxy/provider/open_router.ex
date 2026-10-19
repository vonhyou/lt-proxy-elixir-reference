defmodule LtProxy.Provider.OpenRouter do
  @moduledoc "OpenRouter: OpenAI format plus zero-data-retention routing."

  @behaviour LtProxy.Provider

  alias LtProxy.Provider.OpenAI

  @impl true
  def default_url, do: "https://openrouter.ai/api/v1"

  @impl true
  def default_model, do: "anthropic/claude-haiku-5.5"

  @impl true
  def features, do: %{zdr: true, models: true}

  @impl true
  def headers(key), do: OpenAI.headers(key) ++ [x_title: "lt_proxy"]

  @impl true
  def chat_request(%{zdr: zdr} = chat) do
    [url: url, json: json] = OpenAI.chat_request(chat)
    [url: url, json: Map.put(json, :provider, %{zdr: zdr})]
  end

  @impl true
  defdelegate parse_chat(body), to: OpenAI

  @impl true
  defdelegate parse_models(body), to: OpenAI
end
