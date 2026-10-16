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
end
