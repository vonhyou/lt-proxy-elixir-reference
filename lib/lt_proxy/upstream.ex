defmodule LtProxy.Upstream do
  @moduledoc "OpenRouter chat completions client."

  alias LtProxy.Config
  alias LtProxy.Translate.Prompt

  @type error :: {:upstream_status, pos_integer()} | {:transport, term()} | :empty_reply

  @doc "Sends `messages` to the configured model; `params` are merged into the request body."
  @spec chat([Prompt.message()], map()) :: {:ok, String.t(), map() | nil} | {:error, error()}
  def chat(messages, params \\ %{}) do
    body =
      Map.merge(
        %{
          model: Config.fetch!(:model),
          messages: messages,
          max_tokens: 4096,
          provider: %{zdr: Config.fetch!(:zdr)}
        },
        params
      )

    case Req.post(client(), url: "/chat/completions", json: body) do
      {:ok, %Req.Response{status: 200, body: %{"choices" => [choice | _]} = body}} ->
        content(choice, body["usage"])

      {:ok, %Req.Response{status: 200}} ->
        {:error, :empty_reply}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:upstream_status, status}}

      {:error, exception} ->
        {:error, {:transport, Map.get(exception, :reason, exception)}}
    end
  end

  defp content(%{"message" => %{"content" => content}}, usage)
       when is_binary(content) and content != "",
       do: {:ok, content, usage}

  defp content(_choice, _usage), do: {:error, :empty_reply}

  defp client do
    Req.new(
      base_url: "https://openrouter.ai/api/v1",
      auth: {:bearer, Config.fetch!(:openrouter_key)},
      headers: [x_title: "lt_proxy"],
      receive_timeout: Config.fetch!(:upstream_timeout_ms),
      retry: :transient,
      max_retries: 1
    )
    |> Req.merge(Application.get_env(:lt_proxy, :req_options, []))
  end
end
