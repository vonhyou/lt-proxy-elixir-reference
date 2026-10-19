defmodule LtProxy.Provider.Anthropic do
  @moduledoc "Anthropic Messages API."

  @behaviour LtProxy.Provider

  @version "2023-06-01"
  @default_max_tokens 1024

  @impl true
  def default_url, do: "https://api.anthropic.com/v1"

  @impl true
  def default_model, do: "claude-haiku-5-5"

  @impl true
  def features, do: %{zdr: false, models: true}

  @impl true
  def headers(key), do: [x_api_key: key, anthropic_version: @version]

  @impl true
  def chat_request(%{model: model, messages: messages, params: params}) do
    {system, messages} = Enum.split_with(messages, &(&1.role == "system"))

    body =
      %{model: model, messages: messages, max_tokens: @default_max_tokens}
      |> Map.merge(params)
      |> put_system(Enum.map_join(system, "\n\n", & &1.content))

    [url: "/messages", json: body]
  end

  @impl true
  def parse_chat(%{"content" => content} = body) when is_list(content) do
    case Enum.map_join(content, "", &text/1) do
      "" -> {:error, :empty_reply}
      text -> {:ok, text, usage(body["usage"])}
    end
  end

  def parse_chat(_body), do: {:error, :empty_reply}

  @impl true
  def parse_models(%{"data" => models}) when is_list(models),
    do: models |> Enum.flat_map(&List.wrap(&1["id"])) |> Enum.sort()

  def parse_models(_body), do: []

  defp put_system(body, ""), do: body
  defp put_system(body, system), do: Map.put(body, :system, system)

  defp text(%{"type" => "text", "text" => text}), do: text
  defp text(_block), do: ""

  defp usage(%{"input_tokens" => input, "output_tokens" => output} = usage),
    do: Map.put(usage, "total_tokens", input + output)

  defp usage(usage), do: usage
end
