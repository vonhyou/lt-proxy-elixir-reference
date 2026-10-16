# LtProxy

A [LibreTranslate](https://docs.libretranslate.com/api/)-compatible translation API backed by an LLM through [OpenRouter](https://openrouter.ai).
Built for Misskey/Sharkey instances, whose only self-hostable translation backend is LibreTranslate.

## API

| Method | Path | Description |
|---|---|---|
| `POST` | `/translate` | JSON or form body: `q`, `source` (default `auto`), `target`, `format` (`text` or `html`), `api_key` |
| `GET` | `/languages` | Advertised languages; any ISO 639 code is accepted as a target |
| `GET` | `/health` | Returns `ok` |

```console
$ curl -s localhost:5000/translate -H 'content-type: application/json' \
    -d '{"q": "Bonjour !", "source": "auto", "target": "en", "api_key": "secret"}'
{"detectedLanguage":{"confidence":90.0,"language":"fr"},"translatedText":"Hello!"}
```

Errors return `{"error": "..."}` with status 400 (bad params), 403 (bad key), 413 (body too large), 429 (rate limited), 502 (upstream failure) or 503 (overloaded).

## Configuration

| Variable | Description |
|---|---|
| `OPENROUTER_API_KEY` | OpenRouter API key (required) |
| `LTP_API_KEYS` | Comma-separated `name:key` pairs, keys at least 24 characters (required in production) |
| `LTP_ADMIN_PASSWORD` | Enables the admin panel; log in as `admin` |
| `LTP_ADMIN_HOSTS` | Hostnames allowed for the panel, default `localhost,127.0.0.1` |

See `.env.example`. Everything else has a sensible default; settings changed in the admin panel are saved to `settings.json` in the data directory and override the environment.

<details>
<summary>Advanced</summary>

| Variable | Default | Editable in panel | Description |
|---|---|---|---|
| `LTP_MODEL` | `anthropic/claude-haiku-5.5` | yes | OpenRouter model or `@preset/...` |
| `LTP_ZDR` | `true` | yes | Route only to zero-data-retention providers |
| `LTP_UPSTREAM_TIMEOUT_MS` | `15000` | yes | Upstream time budget per request |
| `LTP_MAX_CONCURRENCY` | `4` | yes | Concurrent upstream calls; excess requests get 503 |
| `LTP_RPM` | unset | yes | Global requests-per-minute limit |
| `LTP_CACHE_TTL_HOURS` | `168` | yes | Translation cache lifetime |
| `LTP_MAX_BODY_BYTES` | `100000` | yes | Request body limit; the URL length limit (3× this) applies after a restart |
| `LTP_CACHE_LIMIT` | `10000` | | Maximum cached translations |
| `LTP_PORT` / `LTP_BIND` | `5000` / `0.0.0.0` | | API port and bind address |
| `LTP_ADMIN_PORT` / `LTP_ADMIN_BIND` | `5001` / `127.0.0.1` (`0.0.0.0` in the image) | | Admin port and bind address |
| `LTP_DATA_DIR` | `data` (`/app/data` in the image) | | Settings and generated secrets |
| `SECRET_KEY_BASE` | generated in the data directory | | Signs admin sessions |

</details>

The proxy cache is separate from Sharkey's own translation cache, and clearing one does not clear the other.

## Admin panel

Use a strong password: anything that can reach the admin port can try it. Keep the panel private. Reach it through an SSH tunnel (`ssh -L 5001:localhost:5001 host`) or a private network such as NetBird, adding the hostname you use to `LTP_ADMIN_HOSTS`. Behind a reverse proxy, enable WebSocket support.

## Running

With Compose:

```console
$ cp .env.example .env               # fill in the keys
$ docker compose -f compose.example.yml up -d
```

This publishes the API on port 5000 and the admin panel on the host's loopback only (`127.0.0.1:5001`).

Images for `linux/amd64` and `linux/arm64` are published to `ghcr.io/vonhyou/lt-proxy-elixir-reference` on version tags, as Debian slim (`latest`, `x.y.z`) and Alpine (`latest-alpine`, `x.y.z-alpine`). To build locally, use `Dockerfile` or `Dockerfile.alpine`:

```console
$ podman build -t lt_proxy .        # or docker; add -f Dockerfile.alpine for Alpine
$ podman run -p 5000:5000 -v lt-proxy-data:/app/data --env-file .env lt_proxy
```

A shell into the running release is available with `bin/lt_proxy remote`.

## Sharkey setup

In *Control panel → External services*:

- **LibreTranslate URL**: `http://lt-proxy:5000/translate`
- **LibreTranslate API key**: one of the configured API keys
- **Translation timeout**: raise from the default 5000 ms to about 20000 ms

Setting a credit limit on the OpenRouter key is recommended.

## Development

Requires Elixir 1.20 and OTP 28+.

```console
$ mix setup                                 # deps, asset tools, assets
$ OPENROUTER_API_KEY=sk-or-... iex -S mix   # API keys are optional in dev
$ mix check                                 # format, warnings, tests (also run by CI on pull requests)
```
