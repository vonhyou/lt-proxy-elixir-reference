defmodule LtProxyWeb.ApiRouter do
  use LtProxyWeb, :router

  # log: false keeps params (note text, api_key) out of the dispatch log.
  scope "/", LtProxyWeb, log: false do
    get "/health", TranslateController, :health
    get "/languages", TranslateController, :languages
    post "/translate", TranslateController, :translate
  end
end
