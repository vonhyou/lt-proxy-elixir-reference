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

API keys, at least 24 characters each; at least one is required in production:

| Variable | Description |
|---|---|
| `LTP_API_KEYS` | Comma-separated `name:key` pairs |
| `LTP_API_KEYS_FILE` | File with one `name:key` per line |
| `LTP_API_KEY` | Legacy single key, named `default` |
| `OPENROUTER_API_KEY` | OpenRouter API key (required) |

Settings marked *editable* can be changed in the admin panel. Changes are saved to `$LTP_DATA_DIR/settings.json` and override the environment.

| Variable | Default | Editable | Description |
|---|---|---|---|
| `LTP_MODEL` | `anthropic/claude-haiku-5.5` | yes | OpenRouter model or `@preset/...` |
| `LTP_ZDR` | `true` | yes | Route only to zero-data-retention providers |
| `LTP_UPSTREAM_TIMEOUT_MS` | `15000` | yes | Upstream time budget per request |
| `LTP_MAX_CONCURRENCY` | `4` | yes | Concurrent upstream calls; excess requests get 503 |
| `LTP_CACHE_TTL_HOURS` | `168` | yes | Translation cache lifetime |
| `LTP_MAX_BODY_BYTES` | `100000` | yes | Request body limit; the URL length limit (3× this) applies after a restart |
| `LTP_RPM` | unset | yes | Global requests-per-minute limit |
| `LTP_PORT` | `5000` | | API port |
| `LTP_BIND` | `0.0.0.0` | | API bind address |
| `LTP_CACHE_LIMIT` | `10000` | | Maximum cached translations |
| `LTP_DATA_DIR` | `data`, `/app/data` in the image | | Directory for `settings.json` |

The proxy cache is separate from Sharkey's own translation cache, and clearing one does not clear the other.

## Admin panel

The admin panel starts only when `LTP_ADMIN_PASSWORD` is set. Log in as `admin` with that password.

| Variable | Default | Description |
|---|---|---|
| `LTP_ADMIN_PASSWORD` | unset | Admin password; enables the panel |
| `SECRET_KEY_BASE` | | Required with the panel; generate with `openssl rand -base64 48` |
| `LTP_ADMIN_PORT` | `5001` | Admin port |
| `LTP_ADMIN_BIND` | `127.0.0.1` | Admin bind address |
| `LTP_ADMIN_HOSTS` | `localhost,127.0.0.1` | Allowed `Host` values and WebSocket origins |

Use a strong password: anything that can reach the admin port can try it. Keep the panel private. Reach it through an SSH tunnel (`ssh -L 5001:localhost:5001 host`) or a private network such as NetBird, adding the hostname you use to `LTP_ADMIN_HOSTS`. Behind a reverse proxy, enable WebSocket support.

## Running

```console
$ podman build -t lt_proxy .        # or docker
$ podman run -p 5000:5000 -v lt-proxy-data:/app/data \
    -e LTP_API_KEYS=sharkey:<key> -e OPENROUTER_API_KEY=sk-or-... lt_proxy
```

See `compose.example.yml` for running next to Sharkey on its internal network, with the admin panel published on the host's loopback only.
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
$ mix check                                 # format, warnings, tests
```
