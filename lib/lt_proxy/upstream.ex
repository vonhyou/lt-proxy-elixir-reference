defmodule LtProxy.Upstream do
  @moduledoc "Calls the configured provider with a hard time budget."

  alias LtProxy.Config
  alias LtProxy.Translate.Prompt

  @type error :: {:upstream_status, pos_integer()} | {:transport, term()} | :empty_reply

  @doc "Sends `messages` to the configured model; `params` are merged into the request body."
  @spec chat([Prompt.message()], map()) ::
          {:ok, String.t(), LtProxy.Provider.usage()} | {:error, error()}
  def chat(messages, params \\ %{}) do
    provider = Config.fetch!(:provider)

    request =
      provider.chat_request(%{
        model: Config.fetch!(:model),
        messages: messages,
        params: params,
        zdr: Config.fetch!(:zdr)
      })

    with {:ok, body} <- post(request), do: provider.parse_chat(body)
  end

  @doc "Model ids offered by the provider, when it can list them."
  @spec models() :: {:ok, [String.t()]} | {:error, error()}
  def models do
    provider = Config.fetch!(:provider)

    with {:ok, body} <- call(&Req.get(&1, url: "/models")),
         do: {:ok, provider.parse_models(body)}
  end

  defp post(request), do: call(&Req.post(&1, request))

  defp call(fun) do
    timeout = Config.fetch!(:upstream_timeout_ms)
    req = client(timeout)
    task = Task.Supervisor.async_nolink(LtProxy.TaskSupervisor, fn -> fun.(req) end)

    case Task.yield(task, timeout + 500) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, %Req.Response{status: 200, body: %{} = body}}} -> {:ok, body}
      {:ok, {:ok, %Req.Response{status: 200}}} -> {:error, :empty_reply}
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
