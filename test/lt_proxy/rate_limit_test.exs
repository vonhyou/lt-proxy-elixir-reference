defmodule LtProxy.RateLimitTest do
  use ExUnit.Case, async: false

  alias LtProxy.RateLimit

  test "decide/2" do
    assert :ok = RateLimit.decide(1, 2)
    assert :ok = RateLimit.decide(2, 2)
    assert {:error, :rate_limited} = RateLimit.decide(3, 2)
  end

  describe "with a limit" do
    setup do
      Application.put_env(:lt_proxy, :rpm, 2)
      on_exit(fn -> Application.put_env(:lt_proxy, :rpm, nil) end)
      %{pid: start_supervised!(RateLimit)}
    end

    test "limits requests per minute" do
      now = 10 * 60_000

      assert :ok = RateLimit.check(now)
      assert :ok = RateLimit.check(now + 1)
      assert {:error, :rate_limited} = RateLimit.check(now + 2)
      assert :ok = RateLimit.check(now + 60_000)
    end

    test "is restarted by its supervisor", %{pid: pid} do
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

      await_restart(pid)
      assert :ok = RateLimit.check(0)
    end
  end

  test "is a no-op when disabled" do
    assert :ok = RateLimit.check()
  end

  defp await_restart(old) do
    case Process.whereis(RateLimit) do
      pid when is_pid(pid) and pid != old ->
        pid

      _ ->
        Process.sleep(5)
        await_restart(old)
    end
  end
end
