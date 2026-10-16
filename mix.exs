defmodule LtProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :lt_proxy,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [lt_proxy: [include_executables_for: [:unix]]]
    ]
  end

  def cli do
    [preferred_envs: [check: :test]]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {LtProxy.Application, []}
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.13"},
      {:cachex, "~> 4.1"},
      {:req, "~> 0.7.5"}
    ]
  end

  defp aliases do
    [
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test --warnings-as-errors"
      ]
    ]
  end
end
