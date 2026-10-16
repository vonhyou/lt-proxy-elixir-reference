defmodule LtProxy.Application do
  @moduledoc false

  use Application

  alias LtProxy.Config

  @impl Application
  def start(_type, _args) do
    LtProxy.ApiKeys.load!()

    base = [
      {Phoenix.PubSub, name: LtProxy.PubSub},
      {Task.Supervisor, name: LtProxy.TaskSupervisor},
      LtProxy.Settings
    ]

    with {:ok, sup} <-
           Supervisor.start_link(base, strategy: :one_for_one, name: LtProxy.Supervisor) do
      # Started after Settings so they read published values (including settings.json).
      for child <- children(), do: {:ok, _pid} = Supervisor.start_child(sup, child)
      {:ok, sup}
    end
  end

  defp children do
    line_length = 3 * Config.fetch!(:max_body_bytes) + 1024

    Enum.filter(
      [
        {LtProxy.Cache, limit: Config.fetch!(:cache_limit)},
        LtProxy.RateLimit,
        {LtProxyWeb.ApiEndpoint, http: [http_1_options: [max_request_line_length: line_length]]},
        LtProxyWeb.AdminEndpoint.enabled?() &&
          {LtProxyWeb.AdminEndpoint, secret_key_base: LtProxyWeb.AdminEndpoint.secret_key_base()}
      ],
      & &1
    )
  end
end
