defmodule LtProxy.ApiKeysTest do
  use ExUnit.Case, async: false

  alias LtProxy.ApiKeys

  @vars ~w(LTP_API_KEYS LTP_API_KEYS_FILE LTP_API_KEY)
  @alice String.duplicate("a", 24)
  @bob String.duplicate("b", 23) <> "z"

  setup do
    saved = Map.new(@vars, &{&1, System.get_env(&1)})
    Enum.each(@vars, &System.delete_env/1)

    on_exit(fn ->
      for {var, value} <- saved,
          do: if(value, do: System.put_env(var, value), else: System.delete_env(var))

      ApiKeys.load!()
    end)

    put_setting(:require_api_keys, true)
  end

  test "loads keys from LTP_API_KEYS" do
    System.put_env("LTP_API_KEYS", "alice:#{@alice}, bob:#{@bob}")
    ApiKeys.load!()

    assert {:ok, "alice"} = ApiKeys.authenticate(@alice)
    assert {:ok, "bob"} = ApiKeys.authenticate(@bob)
    assert [%{name: "alice", last4: "aaaa"}, %{name: "bob", last4: "bbbz"}] = ApiKeys.list()
  end

  test "loads keys from LTP_API_KEYS_FILE" do
    path = Path.join(System.tmp_dir!(), "ltp_api_keys_#{System.unique_integer([:positive])}")
    File.write!(path, "alice:#{@alice}\n\nbob:#{@bob}\n")
    on_exit(fn -> File.rm(path) end)
    System.put_env("LTP_API_KEYS_FILE", path)
    ApiKeys.load!()

    assert {:ok, "alice"} = ApiKeys.authenticate(@alice)
    assert {:ok, "bob"} = ApiKeys.authenticate(@bob)
  end

  test "treats LTP_API_KEY as the default key" do
    System.put_env("LTP_API_KEY", @alice)
    ApiKeys.load!()

    assert {:ok, "default"} = ApiKeys.authenticate(@alice)
    assert [%{name: "default"}] = ApiKeys.list()
  end

  test "rejects unknown and missing keys" do
    System.put_env("LTP_API_KEYS", "alice:#{@alice}")
    ApiKeys.load!()

    assert :error = ApiKeys.authenticate(@bob)
    assert :error = ApiKeys.authenticate(nil)
  end

  test "rejects duplicate names, short keys and malformed entries without leaking keys" do
    for {value, message} <- [
          {"alice:#{@alice},alice:#{@bob}", ~r/duplicate API key name "alice"/},
          {"alice:#{@alice},bob:#{String.slice(@bob, 0, 23)}", ~r/"bob".*shorter than 24/},
          {"alice:#{@alice},#{@bob}", ~r/malformed API key at LTP_API_KEYS entry 2/}
        ] do
      System.put_env("LTP_API_KEYS", value)
      error = assert_raise RuntimeError, message, &ApiKeys.load!/0
      refute error.message =~ "aaaa" or error.message =~ "bbbb"
    end
  end

  test "requires keys unless disabled" do
    assert_raise RuntimeError, ~r/no API keys configured/, &ApiKeys.load!/0

    put_setting(:require_api_keys, false)
    ApiKeys.load!()

    assert {:ok, "anonymous"} = ApiKeys.authenticate(nil)
    assert :ok = ApiKeys.record_use("anonymous")
    assert [] = ApiKeys.list()
  end

  test "record_use updates list" do
    System.put_env("LTP_API_KEYS", "alice:#{@alice},bob:#{@bob}")
    ApiKeys.load!()

    assert [%{requests: 0, last_used_at: nil}, %{requests: 0}] = ApiKeys.list()

    ApiKeys.record_use("alice")
    ApiKeys.record_use("alice")
    ApiKeys.record_use("nobody")

    assert [%{name: "alice", requests: 2, last_used_at: %DateTime{}}, %{requests: 0}] =
             ApiKeys.list()
  end

  defp put_setting(key, value) do
    previous = Application.fetch_env(:lt_proxy, key)
    Application.put_env(:lt_proxy, key, value)

    on_exit(fn ->
      with {:ok, value} <- previous, do: Application.put_env(:lt_proxy, key, value)
      if previous == :error, do: Application.delete_env(:lt_proxy, key)
    end)
  end
end
