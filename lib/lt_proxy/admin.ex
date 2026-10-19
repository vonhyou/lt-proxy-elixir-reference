defmodule LtProxy.Admin do
  @moduledoc "Facade for the admin LiveViews."

  alias LtProxy.{ApiKeys, Cache, Config, Provider, RateLimit, Settings, Slots, Translator}
  alias LtProxy.Translate.{Prompt, Request}

  @secrets [:provider_key]

  @spec status() :: map()
  def status do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)

    %{
      slots_in_use: Slots.in_use(),
      max_concurrency: Config.fetch!(:max_concurrency),
      cache_entries: Cache.size(),
      requests_this_minute: RateLimit.current_count(),
      uptime_s: div(uptime_ms, 1000),
      provider: Provider.name(Config.fetch!(:provider)),
      model: Config.fetch!(:model),
      prompt_version: Prompt.version(),
      keys: ApiKeys.list()
    }
  end

  @doc "Settings plus secrets, which are masked to their last 4 characters."
  @spec settings() :: [map()]
  def settings do
    secrets =
      for key <- @secrets do
        %{key: key, value: mask(Config.fetch!(key)), source: :env, editable: false, secret: true}
      end

    provider = Config.fetch!(:provider)

    Settings.all()
    |> Enum.reject(&(&1.key == :zdr and not provider.features().zdr))
    |> Enum.map(fn
      %{key: :provider, value: module} = s -> %{s | value: Provider.name(module)}
      s -> s
    end)
    |> Enum.map(&Map.put(&1, :secret, false))
    |> Kernel.++(secrets)
  end

  @spec validate_settings(map()) :: :ok | {:error, %{atom() => String.t()}}
  def validate_settings(params), do: Settings.validate(params)

  @spec update_settings(map()) :: :ok | {:error, %{atom() => String.t()}}
  def update_settings(params), do: Settings.update(params)

  @spec clear_cache() :: :ok
  def clear_cache, do: Cache.clear()

  @spec create_key(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def create_key(name), do: ApiKeys.create(name)

  @spec revoke_key(String.t()) :: :ok | {:error, String.t()}
  def revoke_key(name), do: ApiKeys.revoke(name)

  @spec test_translate(String.t(), String.t()) ::
          {:ok, %{text: String.t(), lang: String.t() | nil, ms: non_neg_integer()}}
          | {:error, term()}
  def test_translate(text, target) do
    with {:ok, request} <- Request.from_params(%{"q" => text, "target" => target}) do
      {elapsed, result} = :timer.tc(fn -> Translator.translate(request) end, :millisecond)
      with {:ok, translation} <- result, do: {:ok, Map.put(translation, :ms, elapsed)}
    end
  end

  defp mask(nil), do: nil
  defp mask(secret), do: "••••" <> String.slice(secret, -4, 4)
end
