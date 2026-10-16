defmodule LtProxy.RateLimit do
  @moduledoc "Counts requests per minute; rejects those over `:rpm` when it is set."

  use GenServer

  alias LtProxy.Config

  @table __MODULE__
  @minute 60_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec check(integer()) :: :ok | {:error, :rate_limited}
  def check(now_ms \\ System.system_time(:millisecond)) do
    minute = div(now_ms, @minute)
    @table |> :ets.update_counter(minute, 1, {minute, 0}) |> decide(Config.fetch!(:rpm))
  end

  @spec current_count(integer()) :: non_neg_integer()
  def current_count(now_ms \\ System.system_time(:millisecond)) do
    case :ets.lookup(@table, div(now_ms, @minute)) do
      [{_minute, count}] -> count
      [] -> 0
    end
  end

  @spec decide(non_neg_integer(), pos_integer() | nil) :: :ok | {:error, :rate_limited}
  def decide(_count, nil), do: :ok
  def decide(count, limit) when count <= limit, do: :ok
  def decide(_count, _limit), do: {:error, :rate_limited}

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    schedule_sweep()
    {:ok, nil}
  end

  @impl GenServer
  def handle_info(:sweep, state) do
    current = div(System.system_time(:millisecond), @minute)
    :ets.select_delete(@table, [{{:"$1", :_}, [{:<, :"$1", current}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @minute)
end
