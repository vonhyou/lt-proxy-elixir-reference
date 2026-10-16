ExUnit.after_suite(fn _ -> File.rm_rf!(Application.fetch_env!(:lt_proxy, :data_dir)) end)
ExUnit.start(capture_log: true)
