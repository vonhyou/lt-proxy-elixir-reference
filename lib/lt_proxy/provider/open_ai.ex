defmodule LtProxy.Provider.OpenAI do
  @moduledoc "Any OpenAI-compatible chat completions endpoint; URL and model come from the environment."

  @behaviour LtProxy.Provider

  @impl true
  def default_url, do: nil

  @impl true
  def default_model, do: nil

  @impl true
  def features, do: %{zdr: false, models: true}

  @impl true
  def headers(key), do: [authorization: "Bearer " <> key]

  @impl true
  def chat_request(%{model: model, messages: messages, params: params}),
    do: [url: "/chat/completions", json: Map.merge(%{model: model, messages: messages}, params)]

  @impl true
  def parse_chat(%{"choices" => [%{"message" => %{"content" => content}} | _]} = body)
      when is_binary(content) and content != "",
      do: {:ok, content, body["usage"]}

  def parse_chat(_body), do: {:error, :empty_reply}

  @impl true
  def parse_models(%{"data" => models}) when is_list(models),
    do: models |> Enum.flat_map(&List.wrap(&1["id"])) |> Enum.sort()

  def parse_models(_body), do: []
end
