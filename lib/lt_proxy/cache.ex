defmodule LtProxy.Cache do
  @moduledoc """
  Translation cache. Concurrent fetches of the same key share one loader call;
  errors are never cached. Each entry expires after the `:cache_ttl_ms` current at commit.
  """

  import Cachex.Spec

  alias LtProxy.Config
  alias LtProxy.Translate.{Prompt, Request}

  @name :translations

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    limit = Keyword.fetch!(opts, :limit)
    hooks = [hook(module: Cachex.Limit.Scheduled, args: {limit, [], []})]
    Supervisor.child_spec({Cachex, name: @name, hooks: hooks}, id: __MODULE__)
  end

  @spec key(Request.t()) :: binary()
  def key(%Request{} = request) do
    term =
      {Config.fetch!(:model), Prompt.version(), request.source, request.target, request.format,
       request.text}

    :crypto.hash(:sha256, :erlang.term_to_binary(term))
  end

  @spec fetch(binary(), (-> {:ok, value} | {:error, reason})) :: {:ok, value} | {:error, reason}
        when value: term(), reason: term()
  def fetch(key, loader) do
    result =
      Cachex.fetch(@name, key, fn _key ->
        case loader.() do
          {:ok, value} -> {:commit, value, expire: Config.fetch!(:cache_ttl_ms)}
          error -> {:ignore, error}
        end
      end)

    case result do
      {:ok, value} -> {:ok, value}
      {:commit, value} -> {:ok, value}
      {:ignore, error} -> error
      {:error, _reason} = error -> error
    end
  end

  @spec size() :: non_neg_integer()
  def size do
    {:ok, size} = Cachex.size(@name)
    size
  end

  @spec clear() :: :ok
  def clear do
    {:ok, _count} = Cachex.clear(@name)
    :ok
  end
end
