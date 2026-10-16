defmodule LtProxyWeb.ConnCase do
  use ExUnit.CaseTemplate

  @api_key "test-key-0123456789abcdef"

  using do
    quote do
      @endpoint LtProxyWeb.ApiEndpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import LtProxyWeb.ConnCase
    end
  end

  setup _tags do
    System.put_env("LTP_API_KEYS", "test:" <> @api_key)
    LtProxy.ApiKeys.load!()

    on_exit(fn ->
      System.delete_env("LTP_API_KEYS")
      LtProxy.ApiKeys.load!()
    end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def api_key, do: @api_key
end
