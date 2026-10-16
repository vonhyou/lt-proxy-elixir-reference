defmodule LtProxy.ApiKeys do
  @moduledoc "Named API keys, stored as SHA-256 hashes; usage counters live in `:atomics`."

  @key __MODULE__
  @min_length 24

  @type entry :: %{
          name: String.t(),
          last4: String.t(),
          requests: non_neg_integer(),
          last_used_at: DateTime.t() | nil
        }

  @doc "Loads keys from `LTP_API_KEYS` (`name:key,name:key`)."
  @spec load!() :: :ok
  def load! do
    entries = from_list(env("LTP_API_KEYS"))

    validate!(entries)
    indexed = Enum.with_index(entries)

    :persistent_term.put(@key, %{
      hashes: Map.new(indexed, fn {{name, key, _src}, _i} -> {hash(key), name} end),
      indexes: Map.new(indexed, fn {{name, _key, _src}, i} -> {name, i} end),
      keys:
        Enum.map(indexed, fn {{name, key, _src}, i} -> {name, String.slice(key, -4, 4), i} end),
      counters: :atomics.new(max(2 * length(entries), 1), signed: false),
      open: entries == []
    })
  end

  @spec authenticate(String.t() | nil) :: {:ok, String.t()} | :error
  def authenticate(given) do
    case state() do
      %{open: true} ->
        {:ok, "anonymous"}

      %{hashes: hashes} when is_binary(given) ->
        with :error <- Map.fetch(hashes, hash(given)), do: :error

      _ ->
        :error
    end
  end

  @spec record_use(String.t()) :: :ok
  def record_use(name) do
    %{indexes: indexes, counters: ref} = state()

    with {:ok, i} <- Map.fetch(indexes, name) do
      :atomics.add(ref, 2 * i + 1, 1)
      :atomics.put(ref, 2 * i + 2, System.system_time(:millisecond))
    end

    :ok
  end

  @spec list() :: [entry()]
  def list do
    %{keys: keys, counters: ref} = state()

    for {name, last4, i} <- keys do
      last_used = :atomics.get(ref, 2 * i + 2)

      %{
        name: name,
        last4: last4,
        requests: :atomics.get(ref, 2 * i + 1),
        last_used_at: if(last_used > 0, do: DateTime.from_unix!(last_used, :millisecond))
      }
    end
  end

  defp state, do: :persistent_term.get(@key)

  defp hash(key), do: :crypto.hash(:sha256, key)

  defp env(var), do: with("" <- System.get_env(var), do: nil)

  defp from_list(nil), do: []

  defp from_list(value) do
    value
    |> String.split(",")
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, i} -> parse!(entry, "LTP_API_KEYS entry #{i}") end)
  end

  defp parse!(entry, src) do
    case String.split(entry, ":", parts: 2) |> Enum.map(&String.trim/1) do
      [name, key] when name != "" and key != "" -> {name, key, src}
      _ -> raise "malformed API key at #{src}, expected name:key"
    end
  end

  defp validate!([]) do
    if Application.get_env(:lt_proxy, :require_api_keys, true) do
      raise "no API keys configured, set LTP_API_KEYS"
    end
  end

  defp validate!(entries) do
    Enum.reduce(entries, {%{}, %{}}, fn {name, key, src}, {names, hashes} ->
      if String.length(key) < @min_length,
        do: raise("API key #{inspect(name)} (#{src}) is shorter than #{@min_length} characters")

      if prev = names[name],
        do: raise("duplicate API key name #{inspect(name)} (#{prev}, #{src})")

      if prev = hashes[hash(key)],
        do: raise("API keys #{inspect(prev)} and #{inspect(name)} have the same value")

      {Map.put(names, name, src), Map.put(hashes, hash(key), name)}
    end)
  end
end
