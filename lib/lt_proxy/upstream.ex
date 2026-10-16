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

    timeout = Config.fetch!(:upstream_timeout_ms)
    req = client(timeout)

    task =
      Task.Supervisor.async_nolink(LtProxy.TaskSupervisor, fn ->
        Req.post(req, url: "/chat/completions", json: body)
      end)

    case Task.yield(task, timeout + 500) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, %Req.Response{status: 200, body: %{"choices" => [choice | _]} = body}}} ->
        content(choice, body["usage"])

      {:ok, {:ok, %Req.Response{status: 200}}} ->
        {:error, :empty_reply}

      {:ok, {:ok, %Req.Response{status: status}}} ->
        {:error, {:upstream_status, status}}

      {:ok, {:error, exception}} ->
        {:error, {:transport, Map.get(exception, :reason, exception)}}

      {:exit, _reason} ->
        {:error, {:transport, :crashed}}

      nil ->
        {:error, {:transport, :timeout}}
    end
  end

  defp content(%{"message" => %{"content" => content}}, usage)
       when is_binary(content) and content != "",
       do: {:ok, content, usage}

  defp content(_choice, _usage), do: {:error, :empty_reply}

  defp retry?(_request, %Req.TransportError{reason: reason}),
    do: reason in [:closed, :econnrefused]

  defp retry?(_request, _response_or_exception), do: false

  defp client(timeout) do
    Req.new(
      base_url: "https://openrouter.ai/api/v1",
      auth: {:bearer, Config.fetch!(:openrouter_key)},
      headers: [x_title: "lt_proxy"],
      receive_timeout: timeout,
      retry: &retry?/2,
      retry_delay: 100,
      max_retries: 1
    )
    |> Req.merge(Application.get_env(:lt_proxy, :req_options, []))
  end
end
