defmodule LtProxy.Slots do
  @moduledoc "Caps concurrent upstream calls; callers over the cap wait briefly, then are rejected."

  @key __MODULE__
  @in_use 1
  @max 2
  @poll_ms 50

  @doc "Sets the cap; the in-use count survives later calls."
  @spec init(pos_integer()) :: :ok
  def init(max) when is_integer(max) and max > 0 do
    ref =
      with nil <- :persistent_term.get(@key, nil) do
        ref = :atomics.new(2, signed: true)
        :persistent_term.put(@key, ref)
        ref
      end

    :atomics.put(ref, @max, max)
  end

  @spec run((-> result), non_neg_integer()) :: result | {:error, :overloaded} when result: term()
  def run(fun, wait_ms \\ Application.get_env(:lt_proxy, :slot_wait_ms, 3_000))
      when is_function(fun, 0) do
    ref = :persistent_term.get(@key)

    if acquire(ref, System.monotonic_time(:millisecond) + wait_ms) do
      try do
        fun.()
      after
        :atomics.sub(ref, @in_use, 1)
      end
    else
      {:error, :overloaded}
    end
  end

  @spec in_use() :: non_neg_integer()
  def in_use, do: :atomics.get(:persistent_term.get(@key), @in_use)

  defp acquire(ref, deadline) do
    if :atomics.add_get(ref, @in_use, 1) <= :atomics.get(ref, @max) do
      true
    else
      :atomics.sub(ref, @in_use, 1)

      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(@poll_ms)
        acquire(ref, deadline)
      else
        false
      end
    end
  end
end
