defmodule LtProxy.Settings do
  @moduledoc """
  Runtime settings. Editable values come from `settings.json` in `:data_dir`, else the
  environment, else `config/*.exs`. The GenServer is the only writer; reads use `:persistent_term`.
  """

  use GenServer

  require Logger

  alias LtProxy.Slots

  @key __MODULE__
  @editable [:model, :zdr, :upstream_timeout_ms, :max_concurrency, :rpm, :cache_ttl_hours]
  @read_only [
    :provider,
    :provider_url,
    :port,
    :bind,
    :admin_port,
    :admin_bind,
    :admin_hosts,
    :cache_limit,
    :data_dir
  ]
  @fields Map.new(@editable, &{Atom.to_string(&1), &1})

  @type source :: :default | :env | :file
  @type entry :: %{key: atom(), value: term(), source: source(), editable: boolean()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec get(atom()) :: term()
  def get(key) do
    case :persistent_term.get(@key, %{}) do
      %{^key => {value, _source}} -> value
      _ -> Application.fetch_env!(:lt_proxy, key)
    end
  end

  @spec all() :: [entry()]
  def all do
    published = :persistent_term.get(@key)

    editable =
      for key <- @editable do
        {value, source} = Map.fetch!(published, key)
        %{key: key, value: value, source: source, editable: true}
      end

    read_only =
      for key <- @read_only do
        value = Application.get_env(:lt_proxy, key)
        %{key: key, value: value, source: env_source(key), editable: false}
      end

    editable ++ read_only
  end

  @spec update(%{String.t() => String.t()}) :: :ok | {:error, %{atom() => String.t()}}
  def update(params) when is_map(params), do: GenServer.call(__MODULE__, {:update, params})

  @doc "Validates `params` like `update/1` without saving."
  @spec validate(map()) :: :ok | {:error, %{atom() => String.t()}}
  def validate(params) when is_map(params), do: with({:ok, _values} <- cast(params), do: :ok)

  @impl GenServer
  def init(_opts) do
    file = load!(path())
    publish(file)
    {:ok, file}
  end

  @impl GenServer
  def handle_call({:update, params}, _from, file) do
    with {:ok, values} <- cast(params),
         changed = Map.filter(values, fn {key, value} -> value != get(key) end),
         false <- changed == %{},
         new_file = Map.merge(file, changed),
         :ok <- write(path(), new_file) do
      publish(new_file)
      Logger.info("settings updated: #{changed |> Map.keys() |> Enum.join(", ")}")
      {:reply, :ok, new_file}
    else
      true -> {:reply, :ok, file}
      {:error, _errors} = error -> {:reply, error, file}
    end
  end

  defp publish(file) do
    new =
      Map.new(@editable, fn key ->
        case file do
          %{^key => value} -> {key, {value, :file}}
          _ -> {key, {Application.fetch_env!(:lt_proxy, key), env_source(key)}}
        end
      end)

    :persistent_term.put(@key, new)

    {max, _source} = new.max_concurrency
    Slots.init(max)
  end

  defp env_source(key) do
    if key in Application.get_env(:lt_proxy, :env_keys, []), do: :env, else: :default
  end

  defp path, do: Path.join(Application.fetch_env!(:lt_proxy, :data_dir), "settings.json")

  defp load!(path) do
    with {:ok, contents} <- File.read(path),
         {:ok, %{} = json} <- JSON.decode(contents),
         {:ok, values} <- json |> Map.take(Map.keys(@fields)) |> cast() do
      values
    else
      {:error, :enoent} -> %{}
      {:error, %{} = errors} -> raise "invalid #{path}: #{inspect(errors)}"
      _ -> raise "invalid #{path}: expected a JSON object of settings"
    end
  end

  defp write(path, values) do
    tmp = path <> ".tmp"

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(tmp, JSON.encode!(values), [:sync]),
         :ok <- File.rename(tmp, path) do
      :ok
    else
      {:error, reason} ->
        {:error, %{base: "could not save settings: #{:file.format_error(reason)}"}}
    end
  end

  defp cast(params) do
    {values, errors} =
      params
      |> Enum.reject(fn {name, _raw} -> String.starts_with?(to_string(name), "_") end)
      |> Enum.reduce({%{}, %{}}, fn {name, raw}, {values, errors} ->
        case cast_field(to_string(name), raw) do
          {:ok, key, value} -> {Map.put(values, key, value), errors}
          {:error, key, message} -> {values, Map.put(errors, key, message)}
        end
      end)

    if errors == %{}, do: {:ok, values}, else: {:error, errors}
  end

  defp cast_field(name, raw) do
    with {:ok, key} <- Map.fetch(@fields, name),
         {:ok, value} <- cast_value(key, raw) do
      {:ok, key, value}
    else
      :error -> {:error, :base, "unknown or read-only setting: #{name}"}
      {:error, key} -> {:error, key, message(key)}
    end
  end

  defp cast_value(:model, value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, :model}
      model -> {:ok, model}
    end
  end

  defp cast_value(:zdr, value) when value in [true, "true"], do: {:ok, true}
  defp cast_value(:zdr, value) when value in [false, "false"], do: {:ok, false}
  defp cast_value(:rpm, value) when value in [nil, ""], do: {:ok, nil}

  defp cast_value(key, value) when key not in [:model, :zdr] do
    case positive_integer(value) do
      {:ok, int} -> {:ok, int}
      :error -> {:error, key}
    end
  end

  defp cast_value(key, _value), do: {:error, key}

  defp positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp positive_integer(_value), do: :error

  defp message(:model), do: "can't be blank"
  defp message(:zdr), do: "must be true or false"
  defp message(:rpm), do: "must be blank or a positive integer"
  defp message(_key), do: "must be a positive integer"
end
