defmodule LtProxy.SlotsTest do
  use ExUnit.Case, async: false

  alias LtProxy.Slots

  setup do
    Slots.init(1)
    on_exit(fn -> Slots.init(LtProxy.Config.fetch!(:max_concurrency)) end)
  end

  test "rejects callers over the cap" do
    test = self()

    task =
      Task.async(fn ->
        Slots.run(fn ->
          send(test, :running)
          receive do: (:release -> :done)
        end)
      end)

    assert_receive :running
    assert Slots.in_use() == 1
    assert {:error, :overloaded} = Slots.run(fn -> :never end)

    send(task.pid, :release)
    assert Task.await(task) == :done
    assert Slots.in_use() == 0
  end

  test "keeps counting in-flight calls when the cap changes" do
    test = self()

    task =
      Task.async(fn ->
        Slots.run(fn ->
          send(test, :running)
          receive do: (:release -> :done)
        end)
      end)

    assert_receive :running
    Slots.init(2)
    assert Slots.in_use() == 1

    send(task.pid, :release)
    assert Task.await(task) == :done
    assert Slots.in_use() == 0
  end

  test "frees the slot when the function raises" do
    assert_raise RuntimeError, fn -> Slots.run(fn -> raise "boom" end) end
    assert Slots.in_use() == 0
  end
end
