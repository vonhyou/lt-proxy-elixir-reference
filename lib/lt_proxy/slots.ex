defmodule LtProxy.Slots do
  @moduledoc "Caps concurrent upstream calls; callers over the cap are rejected, not queued."

  @key __MODULE__

  @spec init(pos_integer()) :: :ok
  def init(max) when is_integer(max) and max > 0 do
    :persistent_term.put(@key, {:atomics.new(1, signed: true), max})
  end

  @spec run((-> result)) :: result | {:error, :overloaded} when result: term()
  def run(fun) when is_function(fun, 0) do
    {ref, max} = :persistent_term.get(@key)

    if :atomics.add_get(ref, 1, 1) > max do
      :atomics.sub(ref, 1, 1)
      {:error, :overloaded}
    else
      try do
        fun.()
      after
        :atomics.sub(ref, 1, 1)
      end
    end
  end

  @spec in_use() :: non_neg_integer()
  def in_use do
    {ref, _max} = :persistent_term.get(@key)
    :atomics.get(ref, 1)
  end
end
