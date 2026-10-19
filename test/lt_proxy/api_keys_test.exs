defmodule LtProxy.ApiKeysTest do
  use ExUnit.Case, async: false

  alias LtProxy.ApiKeys

  @alice String.duplicate("a", 24)
  @bob String.duplicate("b", 23) <> "z"

  setup do
    saved = System.get_env("LTP_API_KEYS")
    System.delete_env("LTP_API_KEYS")
    path = Path.join(Application.fetch_env!(:lt_proxy, :data_dir), "api_keys.json")
    File.rm(path)

    on_exit(fn ->
      if saved, do: System.put_env("LTP_API_KEYS", saved), else: System.delete_env("LTP_API_KEYS")
      File.rm(path)
      ApiKeys.load!()
    end)

    put_setting(:require_api_keys, true)
    %{path: path}
  end

  test "loads keys from LTP_API_KEYS" do
    System.put_env("LTP_API_KEYS", "alice:#{@alice}, bob:#{@bob}")
    ApiKeys.load!()

    assert {:ok, "alice"} = ApiKeys.authenticate(@alice)
    assert {:ok, "bob"} = ApiKeys.authenticate(@bob)
    assert :error = ApiKeys.authenticate("nope")
    assert :error = ApiKeys.authenticate(nil)

    assert [%{name: "alice", hint: "…aaaa", source: :env}, %{name: "bob", hint: "…bbbz"}] =
             ApiKeys.list()
  end

  test "rejects bad env keys without leaking them" do
    System.put_env("LTP_API_KEYS", "alice:#{@alice}")
    ApiKeys.load!()

    for {value, message} <- [
          {"alice:#{@alice},alice:#{@bob}", ~r/duplicate API key name "alice"/},
          {"alice:#{@alice},bob:#{String.slice(@bob, 0, 23)}", ~r/"bob".*shorter than 24/},
          {"alice:#{@alice},#{@bob}", ~r/malformed API key at LTP_API_KEYS entry 2/},
          {"alice:#{@alice},bob:#{@alice}", ~r/same value/}
        ] do
      System.put_env("LTP_API_KEYS", value)
      error = assert_raise RuntimeError, message, &ApiKeys.load!/0
      refute error.message =~ "aaaa" or error.message =~ "bbbb"
    end

    assert {:ok, "alice"} = ApiKeys.authenticate(@alice), "previous keys stay in effect"
  end

  test "with no keys the API is closed unless not required" do
    ApiKeys.load!()
    assert :error = ApiKeys.authenticate(nil)

    put_setting(:require_api_keys, false)
    ApiKeys.load!()
    assert {:ok, "anonymous"} = ApiKeys.authenticate(nil)
    assert :ok = ApiKeys.record_use("anonymous")
  end

  test "requires a way to get keys" do
    password = Application.fetch_env!(:lt_proxy, :admin_password)
    Application.put_env(:lt_proxy, :admin_password, nil)
    on_exit(fn -> Application.put_env(:lt_proxy, :admin_password, password) end)

    assert_raise RuntimeError, ~r/set LTP_API_KEYS or LTP_ADMIN_PASSWORD/, &ApiKeys.load!/0
  end

  test "creates, uses, persists and revokes keys", %{path: path} do
    ApiKeys.load!()

    assert {:ok, "ltp_" <> _ = key} = ApiKeys.create(" sharkey ")
    assert String.length(key) == 36
    assert {:ok, "sharkey"} = ApiKeys.authenticate(key)
    refute File.read!(path) =~ key

    ApiKeys.record_use("sharkey")

    assert [%{name: "sharkey", source: :file, requests: 1, last_used_at: %DateTime{}} = entry] =
             ApiKeys.list()

    assert entry.hint == String.slice(key, 0, 8) <> "…"
    assert %DateTime{} = entry.created_at

    send(Process.whereis(ApiKeys), :flush)
    ApiKeys.load!()
    assert {:ok, "sharkey"} = ApiKeys.authenticate(key)
    assert [%{requests: 1}] = ApiKeys.list()

    assert :ok = ApiKeys.revoke("sharkey")
    assert :error = ApiKeys.authenticate(key)
    assert [] = ApiKeys.list()
    assert {:error, "unknown key"} = ApiKeys.revoke("sharkey")
  end

  test "validates names and protects env keys" do
    System.put_env("LTP_API_KEYS", "alice:#{@alice}")
    ApiKeys.load!()

    assert {:error, "name must be" <> _} = ApiKeys.create("")
    assert {:error, "name must be" <> _} = ApiKeys.create(String.duplicate("x", 33))
    assert {:error, "a key named \"alice\" already exists"} = ApiKeys.create("alice")
    assert {:error, "keys from LTP_API_KEYS" <> _} = ApiKeys.revoke("alice")
  end

  defp put_setting(key, value) do
    previous = Application.fetch_env!(:lt_proxy, key)
    Application.put_env(:lt_proxy, key, value)
    on_exit(fn -> Application.put_env(:lt_proxy, key, previous) end)
  end
end
