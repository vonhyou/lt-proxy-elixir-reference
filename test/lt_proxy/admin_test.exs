defmodule LtProxy.AdminTest do
  use ExUnit.Case, async: false

  import LtProxy.UpstreamStub

  alias LtProxy.{Admin, Cache}

  setup do
    Cache.clear()
    Req.Test.set_req_test_to_shared()
    :ok
  end

  test "status/0 reports runtime state" do
    assert %{
             slots_in_use: 0,
             max_concurrency: max,
             cache_entries: 0,
             requests_this_minute: requests,
             uptime_s: uptime,
             model: "anthropic/claude-haiku-5.5",
             prompt_version: version,
             keys: keys
           } = Admin.status()

    assert max == LtProxy.Config.fetch!(:max_concurrency)
    assert is_integer(requests) and is_integer(uptime) and is_integer(version)
    assert is_list(keys)
  end

  test "settings/0 masks secrets" do
    settings = Admin.settings()

    assert %{value: "••••-key", secret: true, editable: false} =
             Enum.find(settings, &(&1.key == :openrouter_key))

    assert %{secret: false, editable: true} = Enum.find(settings, &(&1.key == :model))
    refute inspect(settings) =~ "test-openrouter-key"
  end

  test "clear_cache/0 empties the cache" do
    stub()
    assert {:ok, _} = Admin.test_translate("Bonjour", "en")
    assert Admin.status().cache_entries == 1

    assert :ok = Admin.clear_cache()
    assert Admin.status().cache_entries == 0
  end

  test "test_translate/2 returns the translation with timing" do
    stub()
    assert {:ok, %{text: "Hello", lang: "fr", ms: ms}} = Admin.test_translate("Bonjour", "en")
    assert is_integer(ms)
  end

  test "test_translate/2 validates input" do
    assert {:error, :invalid_lang} = Admin.test_translate("Bonjour", "english")
    assert {:error, :missing_text} = Admin.test_translate(" ", "en")
  end
end
