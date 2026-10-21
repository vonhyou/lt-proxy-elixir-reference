defmodule LtProxy.Upstream do
  @moduledoc "Calls the configured provider with a hard time budget."

  alias LtProxy.Config
  alias LtProxy.Translate.Prompt

  @type error ::
          {:upstream_status, pos_integer()}
          | {:transport, term()}
          | LtProxy.Provider.empty_reply()

  @doc "Sends `messages` to the configured model; `params` are merged into the request body."
  @spec chat([Prompt.message()], map()) ::
          {:ok, String.t(), LtProxy.Provider.usage()} | {:error, error()}
  def chat(messages, params \\ %{}) do
    provider = Config.fetch!(:provider)
    model = Config.fetch!(:model)

    chat = %{
      model: model,
      messages: messages,
      params: params,
      zdr: Config.fetch!(:zdr),
      reasoning:
        with(%{} = reasoning <- :persistent_term.get(reasoning_key(model), nil), do: reasoning)
    }

    with {:ok, body} <- post_chat(provider, chat), do: provider.parse_chat(body)
  end

  @doc "Model ids offered by the provider, when it can list them."
  @spec models() :: {:ok, [String.t()]} | {:error, error()}
  def models do
    provider = Config.fetch!(:provider)

    with {:ok, body} <- call(&Req.get(&1, url: "/models")),
         do: {:ok, provider.parse_models(body)}
  end

  defp post_chat(provider, chat) do
    with {:error, {:upstream_status, 400}} = error <- post(provider.chat_request(chat)) do
      case mandatory_reasoning(provider, chat) do
        nil -> error
        reasoning -> post(provider.chat_request(%{chat | reasoning: reasoning}))
      end
    end
  end

  # A model whose reasoning is mandatory rejects it being off; look it up once per model.
  defp mandatory_reasoning(provider, %{model: model, reasoning: nil}) do
    key = reasoning_key(model)

    with :unchecked <- :persistent_term.get(key, :unchecked),
         true <- function_exported?(provider, :mandatory_reasoning, 2),
         {:ok, body} <- call(&Req.get(&1, url: "/models")) do
      reasoning = provider.mandatory_reasoning(body, model)
      :persistent_term.put(key, reasoning || :optional)
      reasoning
    else
      _ -> nil
    end
  end

  defp mandatory_reasoning(_provider, _chat), do: nil

  defp reasoning_key(model), do: {__MODULE__, :reasoning, model}

  defp post(request), do: call(&Req.post(&1, request))

  defp call(fun) do
    timeout = Config.fetch!(:upstream_timeout_ms)
    req = client(timeout)
    task = Task.Supervisor.async_nolink(LtProxy.TaskSupervisor, fn -> fun.(req) end)

    case Task.yield(task, timeout + 500) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, %Req.Response{status: 200, body: %{} = body}}} -> {:ok, body}
      {:ok, {:ok, %Req.Response{status: 200}}} -> {:error, {:empty_reply, nil}}
      {:ok, {:ok, %Req.Response{status: status}}} -> {:error, {:upstream_status, status}}
      {:ok, {:error, exception}} -> {:error, {:transport, Map.get(exception, :reason, exception)}}
      {:exit, _reason} -> {:error, {:transport, :crashed}}
      nil -> {:error, {:transport, :timeout}}
    end
  end

  defp retry?(_request, %Req.TransportError{reason: reason}),
    do: reason in [:closed, :econnrefused]

  defp retry?(_request, _response_or_exception), do: false

  defp client(timeout) do
    provider = Config.fetch!(:provider)

    Req.new(
      base_url: Config.fetch!(:provider_url),
      headers: provider.headers(Config.fetch!(:provider_key)),
      receive_timeout: timeout,
      retry: &retry?/2,
      retry_delay: 100,
      max_retries: 1
    )
    |> Req.merge(Application.get_env(:lt_proxy, :req_options, []))
  end
end
