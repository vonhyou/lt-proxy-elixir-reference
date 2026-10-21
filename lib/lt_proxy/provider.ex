defmodule LtProxy.Provider do
  @moduledoc "Chat-completion API flavours; `LtProxy.Upstream` does the HTTP and timing."

  @type usage :: %{optional(String.t()) => term()} | nil
  @type chat :: %{
          required(:model) => String.t(),
          required(:messages) => [map()],
          required(:params) => map(),
          required(:zdr) => boolean(),
          optional(:reasoning) => map() | nil
        }
  @type empty_reply :: {:empty_reply, finish_reason :: String.t() | nil}

  @callback default_url() :: String.t() | nil
  @callback default_model() :: String.t() | nil
  @callback features() :: %{zdr: boolean(), models: boolean()}
  @callback headers(key :: String.t()) :: keyword()
  @callback chat_request(chat()) :: keyword()
  @callback parse_chat(map()) :: {:ok, String.t(), usage()} | {:error, empty_reply()}
  @callback parse_models(map()) :: [String.t()]
  @doc "The reasoning setting to use for `model` if it rejects reasoning being off, from `/models`."
  @callback mandatory_reasoning(models :: map(), model :: String.t()) :: map() | nil
  @optional_callbacks mandatory_reasoning: 2

  @names %{
    "openrouter" => LtProxy.Provider.OpenRouter,
    "anthropic" => LtProxy.Provider.Anthropic,
    "openai" => LtProxy.Provider.OpenAI
  }

  @spec names() :: [String.t()]
  def names, do: Map.keys(@names)

  @spec fetch!(String.t()) :: module()
  def fetch!(name) do
    case Map.fetch(@names, name) do
      {:ok, module} ->
        module

      :error ->
        raise "unknown provider #{inspect(name)}, expected one of #{Enum.join(names(), ", ")}"
    end
  end

  @spec name(module()) :: String.t()
  def name(module), do: Enum.find_value(@names, fn {name, mod} -> mod == module && name end)
end
