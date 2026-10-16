defmodule LtProxy.Application do
  @moduledoc false

  use Application

  alias LtProxy.Config

  @impl Application
  def start(_type, _args) do
    LtProxy.Slots.init(Config.fetch!(:max_concurrency))

    children =
      [
        {LtProxy.Cache, ttl: Config.fetch!(:cache_ttl_ms), limit: Config.fetch!(:cache_limit)},
        Config.fetch!(:rpm) && LtProxy.RateLimit,
        Config.fetch!(:server) && {Bandit, plug: LtProxy.Web.Router, port: Config.fetch!(:port)}
      ]
      |> Enum.filter(& &1)

    Supervisor.start_link(children, strategy: :one_for_one, name: LtProxy.Supervisor)
  end
end
