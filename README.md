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

| Variable | Default | Description |
|---|---|---|
| `LTP_API_KEY` | required | Key clients must send as `api_key` |
| `OPENROUTER_API_KEY` | required | OpenRouter API key |
| `LTP_MODEL` | `anthropic/claude-haiku-5.5` | OpenRouter model or `@preset/...` |
| `LTP_ZDR` | `true` | Route only to zero-data-retention providers |
| `LTP_PORT` | `5000` | HTTP port |
| `LTP_UPSTREAM_TIMEOUT_MS` | `15000` | Upstream receive timeout |
| `LTP_MAX_CONCURRENCY` | `4` | Concurrent upstream calls; excess requests get 503 |
| `LTP_CACHE_TTL_HOURS` | `168` | Translation cache lifetime |
| `LTP_CACHE_LIMIT` | `10000` | Maximum cached translations |
| `LTP_MAX_BODY_BYTES` | `100000` | Request body limit |
| `LTP_RPM` | unset | Global requests-per-minute limit |

## Running

```console
$ podman build -t lt_proxy .        # or docker
$ podman run -p 5000:5000 -e LTP_API_KEY=secret -e OPENROUTER_API_KEY=sk-or-... lt_proxy
```

See `compose.example.yml` for running next to Sharkey on its internal network.
A shell into the running release is available with `bin/lt_proxy remote`.

## Sharkey setup

In *Control panel → External services*:

- **LibreTranslate URL**: `http://lt-proxy:5000/translate`
- **LibreTranslate API key**: the value of `LTP_API_KEY`
- **Translation timeout**: raise from the default 5000 ms to about 20000 ms

Setting a credit limit on the OpenRouter key is recommended.

## Development

Requires Elixir 1.20 and OTP 28+.

```console
$ mix deps.get
$ OPENROUTER_API_KEY=sk-or-... iex -S mix   # LTP_API_KEY is optional in dev
$ mix check                                 # format, warnings, tests
```
