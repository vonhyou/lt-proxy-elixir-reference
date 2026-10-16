defmodule LtProxyWeb.Admin.EndpointTest do
  use ExUnit.Case, async: false

  alias LtProxyWeb.AdminEndpoint

  test "enabled only when an admin password is set" do
    original = Application.get_env(:lt_proxy, :admin_password)
    on_exit(fn -> Application.put_env(:lt_proxy, :admin_password, original) end)

    assert AdminEndpoint.enabled?()

    for unset <- [nil, ""] do
      Application.put_env(:lt_proxy, :admin_password, unset)
      refute AdminEndpoint.enabled?()
    end
  end

  test "prefers a configured secret_key_base" do
    configured = Application.fetch_env!(:lt_proxy, AdminEndpoint)[:secret_key_base]
    assert AdminEndpoint.secret_key_base("/nonexistent") == configured
  end

  test "otherwise generates a secret_key_base once and keeps it private" do
    config = Application.fetch_env!(:lt_proxy, AdminEndpoint)
    Application.put_env(:lt_proxy, AdminEndpoint, Keyword.delete(config, :secret_key_base))
    dir = Path.join(System.tmp_dir!(), "ltp_secret_#{System.unique_integer([:positive])}")

    on_exit(fn ->
      Application.put_env(:lt_proxy, AdminEndpoint, config)
      File.rm_rf!(dir)
    end)

    secret = AdminEndpoint.secret_key_base(dir)
    assert byte_size(secret) >= 64
    assert AdminEndpoint.secret_key_base(dir) == secret
    assert Bitwise.band(File.stat!(Path.join(dir, "secret_key_base")).mode, 0o777) == 0o600
  end
end
