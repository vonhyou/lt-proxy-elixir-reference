defmodule LtProxy.ApiKeys do
  @moduledoc """
  Named API keys. Keys created in the admin live hashed in `api_keys.json` under `:data_dir`;
  `LTP_API_KEYS` (`name:key,…`) adds read-only ones. Lookups use `:persistent_term`,
  usage counters an ETS table that is flushed to the file when they changed.
  """

  use GenServer

  @table __MODULE__
  @min_length 24
  @max_name 32
  @flush_ms :timer.minutes(1)

  @type entry :: %{
          name: String.t(),
          hint: String.t(),
          source: :env | :file,
          created_at: DateTime.t() | nil,
          requests: non_neg_integer(),
          last_used_at: DateTime.t() | nil
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Re-reads `LTP_API_KEYS` and the key file; raises on invalid env keys."
  @spec load!() :: :ok
  def load! do
    with {:error, message} <- GenServer.call(__MODULE__, :load), do: raise(message)
  end

  @spec authenticate(String.t() | nil) :: {:ok, String.t()} | :error
  def authenticate(given) do
    case :persistent_term.get(@table) do
      %{open: true} -> {:ok, "anonymous"}
      %{by_hash: by_hash} when is_binary(given) -> Map.fetch(by_hash, hash(given))
      _ -> :error
    end
  end

  @spec record_use(String.t()) :: :ok
  def record_use(name) do
    now = System.system_time(:millisecond)
    :ets.update_counter(@table, name, [{2, 1}, {3, 1, 0, now}], {name, 0, 0})
    :ok
  end

  @doc "Creates a key and returns it once; only its hash is kept."
  @spec create(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def create(name), do: GenServer.call(__MODULE__, {:create, String.trim(name)})

  @spec revoke(String.t()) :: :ok | {:error, String.t()}
  def revoke(name), do: GenServer.call(__MODULE__, {:revoke, name})

  @spec list() :: [entry()]
  def list do
    for key <- :persistent_term.get(@table).keys do
      {requests, last_used} = counters(key.name)

      key
      |> Map.take([:name, :hint, :source, :created_at])
      |> Map.put(:requests, requests)
      |> Map.put(
        :last_used_at,
        if(last_used > 0, do: DateTime.from_unix!(last_used, :millisecond))
      )
    end
  end

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    Process.send_after(self(), :flush, @flush_ms)

    case load() do
      {:ok, state} -> {:ok, state}
      {:error, message} -> {:stop, message}
    end
  end

  @impl GenServer
  def handle_call(:load, _from, state) do
    case load() do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, _message} = error -> {:reply, error, state}
    end
  end

  def handle_call({:create, name}, _from, state) do
    key = "ltp_" <> Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

    entry = %{
      name: name,
      hash: hash(key),
      hint: String.slice(key, 0, 8) <> "…",
      source: :file,
      created_at: DateTime.utc_now(:second)
    }

    with :ok <- validate_name(name, state.keys),
         {:ok, state} <- persist(state, state.keys ++ [entry]) do
      {:reply, {:ok, key}, state}
    else
      {:error, _message} = error -> {:reply, error, state}
    end
  end

  def handle_call({:revoke, name}, _from, state) do
    with %{source: :file} <- Enum.find(state.keys, {:error, "unknown key"}, &(&1.name == name)),
         {:ok, state} <- persist(state, Enum.reject(state.keys, &(&1.name == name))) do
      :ets.delete(@table, name)
      {:reply, :ok, state}
    else
      %{source: :env} ->
        {:reply, {:error, "keys from LTP_API_KEYS can only be removed there"}, state}

      {:error, _message} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_info(:flush, state) do
    Process.send_after(self(), :flush, @flush_ms)

    case persist(state, state.keys) do
      {:ok, state} -> {:noreply, state}
      {:error, _message} -> {:noreply, state}
    end
  end

  defp load do
    path = Path.join(Application.fetch_env!(:lt_proxy, :data_dir), "api_keys.json")

    with {:ok, env_keys} <- env_keys(),
         {:ok, file_keys} <- read(path),
         :ok <- validate(env_keys ++ file_keys) do
      :ets.delete_all_objects(@table)

      for %{name: name, requests: requests, last_used: last_used} <- file_keys,
          do: :ets.insert(@table, {name, requests, last_used})

      keys = env_keys ++ Enum.map(file_keys, &Map.drop(&1, [:requests, :last_used]))
      {:ok, publish(%{path: path, keys: keys, written: encode(keys)})}
    end
  end

  defp publish(%{keys: keys} = state) do
    open = keys == [] and not Application.get_env(:lt_proxy, :require_api_keys, true)

    :persistent_term.put(@table, %{
      keys: keys,
      by_hash: Map.new(keys, &{&1.hash, &1.name}),
      open: open
    })

    state
  end

  # Writes only when the file would change, then publishes the new key set.
  defp persist(state, keys) do
    json = encode(keys)

    with :ok <- if(json == state.written, do: :ok, else: write(state.path, json)) do
      {:ok, publish(%{state | keys: keys, written: json})}
    end
  end

  defp env_keys do
    entries =
      case System.get_env("LTP_API_KEYS", "") do
        "" -> []
        value -> value |> String.split(",") |> Enum.with_index(1)
      end

    Enum.reduce_while(entries, {:ok, []}, fn {entry, i}, {:ok, acc} ->
      case String.split(entry, ":", parts: 2) |> Enum.map(&String.trim/1) do
        [name, key] when name != "" and key != "" ->
          if String.length(key) < @min_length do
            {:halt,
             {:error, "API key #{inspect(name)} is shorter than #{@min_length} characters"}}
          else
            hint = "…" <> String.slice(key, -4, 4)
            entry = %{name: name, hash: hash(key), hint: hint, source: :env, created_at: nil}
            {:cont, {:ok, acc ++ [entry]}}
          end

        _ ->
          {:halt, {:error, "malformed API key at LTP_API_KEYS entry #{i}, expected name:key"}}
      end
    end)
  end

  defp validate(keys) do
    names = Enum.frequencies_by(keys, & &1.name)
    hashes = Enum.frequencies_by(keys, & &1.hash)

    cond do
      dup = Enum.find_value(names, fn {name, n} -> n > 1 && name end) ->
        {:error, "duplicate API key name #{inspect(dup)}"}

      Enum.any?(hashes, fn {_hash, n} -> n > 1 end) ->
        {:error, "two API keys have the same value"}

      keys == [] and Application.get_env(:lt_proxy, :require_api_keys, true) and
          not LtProxyWeb.AdminEndpoint.enabled?() ->
        {:error,
         "no API keys and no admin panel to create them: set LTP_API_KEYS or LTP_ADMIN_PASSWORD"}

      true ->
        :ok
    end
  end

  defp validate_name(name, keys) do
    cond do
      name == "" or String.length(name) > @max_name ->
        {:error, "name must be 1 to #{@max_name} characters"}

      Enum.any?(keys, &(&1.name == name)) ->
        {:error, "a key named #{inspect(name)} already exists"}

      true ->
        :ok
    end
  end

  defp read(path) do
    with {:ok, contents} <- File.read(path),
         {:ok, list} when is_list(list) <- JSON.decode(contents) do
      {:ok, Enum.map(list, &from_json/1)}
    else
      {:error, :enoent} -> {:ok, []}
      _ -> {:error, "invalid #{path}"}
    end
  end

  defp from_json(%{"name" => name, "hash" => hash, "hint" => hint} = json) do
    %{
      name: name,
      hash: Base.decode16!(hash, case: :lower),
      hint: hint,
      source: :file,
      created_at: with({:ok, dt, _} <- DateTime.from_iso8601(json["created_at"] || ""), do: dt),
      requests: json["requests"] || 0,
      last_used: json["last_used"] || 0
    }
  end

  defp encode(keys) do
    for %{source: :file} = key <- keys do
      {requests, last_used} = counters(key.name)

      %{
        name: key.name,
        hash: Base.encode16(key.hash, case: :lower),
        hint: key.hint,
        created_at: key.created_at,
        requests: requests,
        last_used: last_used
      }
    end
    |> JSON.encode!()
  end

  defp write(path, json) do
    tmp = path <> ".tmp"

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(tmp, json, [:sync]),
         :ok <- File.rename(tmp, path) do
      :ok
    else
      {:error, reason} -> {:error, "could not save keys: #{:file.format_error(reason)}"}
    end
  end

  defp counters(name) do
    case :ets.lookup(@table, name) do
      [{_name, requests, last_used}] -> {requests, last_used}
      [] -> {0, 0}
    end
  end

  defp hash(key), do: :crypto.hash(:sha256, key)
end
