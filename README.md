# LtProxy

A [LibreTranslate](https://docs.libretranslate.com/api/)-compatible translation API backed by an LLM.
Built for Misskey/Sharkey instances, whose only self-hostable translation backend is LibreTranslate; also works with TranslateYou and other LibreTranslate clients.

## Quick start

```console
$ cp .env.example .env               # set LTP_PROVIDER_KEY and LTP_ADMIN_PASSWORD
$ docker compose -f compose.example.yml up -d
```

Then open the admin panel at `http://127.0.0.1:5001` (user `admin`), create an API key and paste it into Sharkey. The API listens on port 5000.

## API

| Method | Path | Description |
|---|---|---|
| `POST` | `/translate` | JSON or form body: `q`, `source` (default `auto`), `target`, `format` (`text` or `html`), `api_key` |
| `GET` | `/languages` | Advertised languages; any ISO 639 code is accepted as a target |
| `GET` | `/health` | Returns `ok` |

```console
$ curl -s localhost:5000/translate -H 'content-type: application/json' \
    -d '{"q": "Bonjour !", "source": "auto", "target": "en", "api_key": "ltp_..."}'
{"detectedLanguage":{"confidence":90.0,"language":"fr"},"translatedText":"Hello!"}
```

Errors return `{"error": "..."}` with status 400 (bad params), 403 (bad key), 413 (body too large), 429 (rate limited), 502 (provider failure) or 503 (overloaded).

## Providers

| | OpenRouter (default) | Anthropic | OpenAI-compatible |
|---|---|---|---|
| `LTP_PROVIDER` | `openrouter` | `anthropic` | `openai` |
| Default model | `anthropic/claude-haiku-5.5` | `claude-haiku-5-5` | none, set `LTP_MODEL` |
| `LTP_PROVIDER_URL` | optional | optional | required, e.g. `https://api.example.com/v1` |
| Translation and language detection | yes | yes | yes |
| Model suggestions in the panel | yes | yes | if the endpoint serves `/models` |
| Zero data retention routing | yes | n/a | n/a |

OpenRouter and Anthropic are tested with the prompt evaluation corpus; other OpenAI-compatible endpoints depend on the model following the JSON reply format. Set a spending limit on the provider key.

## Configuration

| Variable | Description |
|---|---|
| `LTP_PROVIDER_KEY` | Provider API key (required) |
| `LTP_ADMIN_PASSWORD` | Enables the admin panel; at least 16 characters |
| `LTP_PROVIDER` | `openrouter`, `anthropic` or `openai` |
| `LTP_API_KEYS` | Optional `name:key,…` pairs (24+ characters) for setups without the panel; these keys are read-only there |

Without a password the panel is off, so `LTP_API_KEYS` becomes mandatory. Settings changed in the panel are saved under the data directory and override the environment.

<details>
<summary>All variables</summary>

| Variable | Default | Editable in panel | Description |
|---|---|---|---|
| `LTP_MODEL` | per provider | yes | Model id as the provider names it |
| `LTP_PROVIDER_URL` | per provider | | API base URL |
| `LTP_ZDR` | `true` | yes | OpenRouter only: route to zero-data-retention providers |
| `LTP_UPSTREAM_TIMEOUT_MS` | `15000` | yes | Time budget per provider request |
| `LTP_MAX_CONCURRENCY` | `4` | yes | Concurrent provider calls; excess requests wait up to 3 s, then get 503 |
| `LTP_RPM` | unset | yes | Requests per minute per API key |
| `LTP_CACHE_TTL_HOURS` | `168` | yes | Translation cache lifetime |
| `LTP_CACHE_LIMIT` | `10000` | | Maximum cached translations |
| `LTP_PORT` / `LTP_BIND` | `5000` / `0.0.0.0` | | API port and bind address |
| `LTP_ADMIN_PORT` / `LTP_ADMIN_BIND` | `5001` / `127.0.0.1` (`0.0.0.0` in the image) | | Admin port and bind address |
| `LTP_ADMIN_HOSTS` | `localhost,127.0.0.1` | | Extra hostnames allowed for the panel; IP addresses always are |
| `LTP_DATA_DIR` | `data` (`/app/data` in the image) | | Settings, API keys and generated secrets |
| `SECRET_KEY_BASE` | generated in the data directory | | Signs admin sessions |

</details>

## Admin panel

Dashboard with a live test, API key management (keys are shown once and stored hashed) and runtime settings. It uses HTTP Basic auth over plain HTTP, so keep the port private: reach it through an SSH tunnel (`ssh -L 5001:localhost:5001 host`) or a private network such as NetBird. Behind a reverse proxy, terminate TLS there, add the hostname to `LTP_ADMIN_HOSTS` and enable WebSocket support. Failed logins are delayed by one second.

## Deployment

`compose.example.yml` publishes the API on port 5000 and the admin panel on the host's loopback only. The same three facts apply to any runtime, including a Podman Quadlet `.container` unit: pass `.env` as the environment file, publish `5000` and `127.0.0.1:5001:5001`, and mount a volume at `/app/data`.

Images for `linux/amd64` and `linux/arm64` are published to `ghcr.io/vonhyou/lt-proxy-elixir-reference` on version tags, as Debian slim (`latest`, `x.y.z`) and Alpine (`latest-alpine`, `x.y.z-alpine`). They run as an unprivileged user with a read-only release and Erlang distribution disabled, so only the two HTTP ports listen. To build locally:

```console
$ podman build -t lt_proxy .        # or docker; add -f Dockerfile.alpine for Alpine
```

## Sharkey setup

In *Control panel → External services*:

- **LibreTranslate URL**: `http://lt-proxy:5000/translate`
- **LibreTranslate API key**: a key created in the panel
- **Translation timeout**: raise from the default 5000 ms to about 20000 ms

The proxy cache is separate from Sharkey's own translation cache.

## Development

Requires Elixir 1.20 and OTP 28+.

```console
$ mix setup                                       # deps, asset tools, assets
$ LTP_PROVIDER_KEY=sk-or-... iex -S mix           # API keys are optional in dev
$ mix check                                       # format, warnings, tests (CI runs it on pull requests)
```
