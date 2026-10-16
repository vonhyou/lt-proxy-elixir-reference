defmodule LtProxyWeb.Plugs.ParseBody do
  @moduledoc "`Plug.Parsers` built per request so `max_body_bytes` stays a runtime setting."

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    opts =
      Plug.Parsers.init(
        parsers: [:urlencoded, :json],
        pass: ["*/*"],
        json_decoder: JSON,
        length: LtProxy.Config.fetch!(:max_body_bytes)
      )

    Plug.Parsers.call(conn, opts)
  end
end
