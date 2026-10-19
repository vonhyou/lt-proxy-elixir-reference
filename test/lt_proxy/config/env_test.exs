defmodule LtProxy.Config.EnvTest do
  use ExUnit.Case, async: false

  alias LtProxy.Config.Env

  test "parses set variables and ignores empty ones" do
    vars = %{
      "LTP_RPM" => "",
      "LTP_MAX_CONCURRENCY" => "3",
      "LTP_ZDR" => "false",
      "LTP_CACHE_TTL_HOURS" => "2",
      "LTP_ADMIN_HOSTS" => "a.example, b.example"
    }

    Enum.each(vars, fn {var, value} -> System.put_env(var, value) end)
    on_exit(fn -> Enum.each(Map.keys(vars), &System.delete_env/1) end)

    env = Env.read()
    refute Keyword.has_key?(env, :rpm)
    assert env[:max_concurrency] == 3
    assert env[:zdr] == false
    assert env[:cache_ttl_hours] == 2
    assert env[:admin_hosts] == ["a.example", "b.example"]
  end

  test "ip!/1 parses addresses and rejects junk" do
    assert Env.ip!("127.0.0.1") == {127, 0, 0, 1}
    assert Env.ip!("::1") == {0, 0, 0, 0, 0, 0, 0, 1}
    assert_raise ArgumentError, fn -> Env.ip!("localhost") end
  end
end
