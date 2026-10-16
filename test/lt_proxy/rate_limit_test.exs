defmodule LtProxy.RateLimitTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias LtProxy.{RateLimit, Settings}

  test "decide/2" do
    assert :ok = RateLimit.decide(1, 2)
    assert :ok = RateLimit.decide(2, 2)
    assert {:error, :rate_limited} = RateLimit.decide(3, 2)
    assert :ok = RateLimit.decide(3, nil)
  end

  describe "with a limit" do
    setup do
      :ok = Settings.update(%{"rpm" => "2"})
      on_exit(fn -> capture_log(fn -> Settings.update(%{"rpm" => ""}) end) end)
    end

    test "limits requests per minute" do
      now = 10 * 60_000

      assert :ok = RateLimit.check(now)
      assert :ok = RateLimit.check(now + 1)
      assert {:error, :rate_limited} = RateLimit.check(now + 2)
      assert :ok = RateLimit.check(now + 60_000)
    end
  end

  test "counts without limiting when disabled" do
    now = 20 * 60_000

    for _ <- 1..3, do: assert(:ok = RateLimit.check(now))
    assert RateLimit.current_count(now) == 3
    assert RateLimit.current_count(now + 60_000) == 0
  end

  test "is restarted by its supervisor" do
    pid = Process.whereis(RateLimit)
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

    await_restart(pid)
    assert :ok = RateLimit.check(0)
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
