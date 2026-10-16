defmodule LtProxy.SettingsTest do
  use ExUnit.Case, async: false

  alias LtProxy.{Cache, Config, Settings, Slots}

  setup do
    previous = Application.fetch_env!(:lt_proxy, :data_dir)
    dir = Path.join(previous, "settings_test_#{System.unique_integer([:positive])}")
    Application.put_env(:lt_proxy, :data_dir, dir)
    restart()

    on_exit(fn ->
      Application.put_env(:lt_proxy, :data_dir, previous)
      restart()
    end)

    %{path: Path.join(dir, "settings.json")}
  end

  test "serves editable and read-only keys like fetch_env!" do
    assert Config.fetch!(:model) == Application.fetch_env!(:lt_proxy, :model)
    assert Config.fetch!(:openrouter_key) == "test-openrouter-key"
    assert Config.fetch!(:port) == 5000
    assert_raise ArgumentError, fn -> Settings.get(:no_such_setting) end
  end

  test "reports default, env and file sources" do
    env_model = Application.fetch_env!(:lt_proxy, :model)
    Application.put_env(:lt_proxy, :model, "env/model")
    Application.put_env(:lt_proxy, :env_keys, [:model, :port])

    on_exit(fn ->
      Application.put_env(:lt_proxy, :model, env_model)
      Application.delete_env(:lt_proxy, :env_keys)
    end)

    restart()
    assert %{value: "env/model", source: :env, editable: true} = entry(:model)
    assert %{source: :env, editable: false} = entry(:port)
    assert %{source: :default, editable: true} = entry(:zdr)
    assert %{source: :default, editable: false} = entry(:cache_limit)

    assert :ok = Settings.update(%{"model" => "file/model", "rpm" => "30"})
    assert %{value: "file/model", source: :file} = entry(:model)
    assert %{value: 30, source: :file} = entry(:rpm)
    assert %{source: :default} = entry(:zdr)
  end

  test "writes nothing when any field is invalid", %{path: file} do
    assert {:error, errors} =
             Settings.update(%{"rpm" => "5", "max_concurrency" => "0", "zdr" => "maybe"})

    assert %{max_concurrency: "must be a positive integer", zdr: "must be true or false"} =
             errors

    refute Map.has_key?(errors, :rpm)
    refute File.exists?(file)
    assert Settings.get(:rpm) == nil

    assert {:error, %{base: _}} = Settings.update(%{"port" => "1"})
    assert {:error, %{base: _}} = Settings.update(%{"openrouter_key" => "sk"})
    assert {:error, %{model: "can't be blank"}} = Settings.update(%{"model" => " "})
    refute File.exists?(file)
  end

  test "parses form values" do
    params = %{
      "model" => " a/b ",
      "zdr" => "false",
      "upstream_timeout_ms" => "2000",
      "rpm" => "",
      "cache_ttl_ms" => "60000",
      "max_body_bytes" => "1000",
      "_unused_model" => ""
    }

    assert :ok = Settings.update(params)
    assert Settings.get(:model) == "a/b"
    assert Settings.get(:zdr) == false
    assert Settings.get(:upstream_timeout_ms) == 2000
    assert Settings.get(:rpm) == nil
    assert Settings.get(:cache_ttl_ms) == 60_000
    assert Settings.get(:max_body_bytes) == 1000
  end

  test "a valid update survives a restart", %{path: file} do
    assert :ok = Settings.update(%{"model" => "x/y", "rpm" => "7", "zdr" => "false"})
    restart()

    assert %{value: "x/y", source: :file} = entry(:model)
    assert %{value: 7, source: :file} = entry(:rpm)
    assert %{value: false, source: :file} = entry(:zdr)
    assert %{source: :default} = entry(:max_concurrency)
    refute File.exists?(file <> ".tmp")
  end

  test "secrets never reach the file", %{path: file} do
    params = %{
      "model" => "m",
      "zdr" => "false",
      "upstream_timeout_ms" => "1",
      "max_concurrency" => "2",
      "rpm" => "3",
      "cache_ttl_ms" => "4",
      "max_body_bytes" => "5"
    }

    assert :ok = Settings.update(params)
    json = File.read!(file)
    refute json =~ "test-key"
    refute json =~ "test-openrouter-key"
    assert json |> JSON.decode!() |> Map.keys() |> Enum.sort() == Enum.sort(Map.keys(params))
  end

  test "max_concurrency applies to slots" do
    assert :ok = Settings.update(%{"max_concurrency" => "1"})
    test = self()

    task =
      Task.async(fn ->
        Slots.run(fn ->
          send(test, :running)
          receive do: (:release -> :done)
        end)
      end)

    assert_receive :running
    assert {:error, :overloaded} = Slots.run(fn -> :never end)
    send(task.pid, :release)
    assert Task.await(task) == :done
  end

  test "cache_ttl_ms applies to newly committed entries" do
    Cache.clear()
    assert :ok = Settings.update(%{"cache_ttl_ms" => "1"})
    assert {:ok, 1} = Cache.fetch("ttl", fn -> {:ok, 1} end)
    assert Cache.size() == 1
    Process.sleep(5)
    assert {:ok, 2} = Cache.fetch("ttl", fn -> {:ok, 2} end)
  end

  defp entry(key), do: Enum.find(Settings.all(), &(&1.key == key))

  test "validate/1 checks without saving", %{path: file} do
    assert :ok = Settings.validate(%{"rpm" => "5"})
    assert {:error, %{max_concurrency: _}} = Settings.validate(%{"max_concurrency" => "0"})
    assert {:error, %{model: _}} = Settings.validate(%{"model" => 1})
    refute File.exists?(file)
    assert Config.fetch!(:rpm) == nil
  end

  test "an unchanged update writes nothing", %{path: file} do
    assert :ok = Settings.update(%{"model" => Config.fetch!(:model)})
    refute File.exists?(file)
  end

  test "an invalid file fails loudly at boot", %{path: file} do
    File.mkdir_p!(Path.dirname(file))

    File.write!(file, ~s({"max_concurrency": 0}))

    assert_raise RuntimeError, ~r/invalid .*settings.json.*max_concurrency/, fn ->
      Settings.init([])
    end

    File.write!(file, "[]")
    assert_raise RuntimeError, ~r/expected a JSON object/, fn -> Settings.init([]) end
  end

  defp restart do
    :ok = Supervisor.terminate_child(LtProxy.Supervisor, Settings)
    {:ok, _pid} = Supervisor.restart_child(LtProxy.Supervisor, Settings)
  end
end
