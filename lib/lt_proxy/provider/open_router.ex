defmodule LtProxy.Provider.OpenRouter do
  @moduledoc "OpenRouter: OpenAI format plus zero-data-retention routing."

  @behaviour LtProxy.Provider

  alias LtProxy.Provider.OpenAI

  @efforts ~w(minimal low medium high xhigh max)

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

    # Reasoning tokens count against max_tokens and add nothing to a translation.
    json =
      json
      |> Map.put(:provider, %{zdr: zdr})
      |> Map.put(:reasoning, chat[:reasoning] || %{effort: "none"})

    [url: url, json: json]
  end

  @impl true
  defdelegate parse_chat(body), to: OpenAI

  @impl true
  defdelegate parse_models(body), to: OpenAI

  @impl true
  def mandatory_reasoning(%{"data" => models}, model) when is_list(models) do
    case Enum.find(models, &(&1["id"] == model)) do
      %{"reasoning" => %{"mandatory" => true} = reasoning} ->
        supported = reasoning["supported_efforts"] || []
        %{effort: Enum.find(@efforts, "low", &(&1 in supported))}

      _ ->
        nil
    end
  end

  def mandatory_reasoning(_body, _model), do: nil
end
