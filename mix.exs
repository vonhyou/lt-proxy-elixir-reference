defmodule LtProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :lt_proxy,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:bandit, "~> 1.13"},
      {:cachex, "~> 4.1"},
      {:req, "~> 0.7.5"},
      {:phoenix, "~> 1.8.15"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.5.20",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind lt_proxy", "esbuild lt_proxy"],
      "assets.deploy": ["tailwind lt_proxy --minify", "esbuild lt_proxy --minify", "phx.digest"],
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test --warnings-as-errors"
      ]
    ]
  end
end
