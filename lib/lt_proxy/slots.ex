defmodule LtProxy.Slots do
  @moduledoc "Caps concurrent upstream calls; callers over the cap are rejected, not queued."

  @key __MODULE__
  @in_use 1
  @max 2

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

  @spec run((-> result)) :: result | {:error, :overloaded} when result: term()
  def run(fun) when is_function(fun, 0) do
    ref = :persistent_term.get(@key)

    if :atomics.add_get(ref, @in_use, 1) > :atomics.get(ref, @max) do
      :atomics.sub(ref, @in_use, 1)
      {:error, :overloaded}
    else
      try do
        fun.()
      after
        :atomics.sub(ref, @in_use, 1)
      end
    end
  end

  @spec in_use() :: non_neg_integer()
  def in_use, do: :atomics.get(:persistent_term.get(@key), @in_use)
end
