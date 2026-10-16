# AGENTS.md

LibreTranslate-compatible proxy to an LLM on OpenRouter, for Sharkey/Misskey. Elixir 1.20, OTP 29, Phoenix 1.8 + LiveView (daisyUI), Bandit, Req, Cachex.

## Layout

- `lib/lt_proxy/translate/` pure modules: `Lang`, `Request`, `Prompt`, `Output`
- `lib/lt_proxy/upstream.ex` OpenRouter client with a hard time budget; `translator.ex` cache → slot → upstream → parse
- `lib/lt_proxy/settings.ex` runtime settings (`settings.json` > env > config); `Config.fetch!/1` reads through it; `lib/lt_proxy/config/env.ex` parses `LTP_*` vars
- `lib/lt_proxy/api_keys.ex` named keys (hashed, read from `LTP_API_KEYS` at boot), `cache.ex` (Cachex, dedupes concurrent loads, never caches errors), `slots.ex` (atomics concurrency cap), `rate_limit.ex` (ETS RPM, always running)
- `lib/lt_proxy/admin.ex` facade for the admin LiveViews
- `lib/lt_proxy_web/` `ApiEndpoint` + `ApiRouter` (sessionless JSON API) and `AdminEndpoint` + `AdminRouter` (LiveView admin, BasicAuth, host check; started only with `LTP_ADMIN_PASSWORD`)
- `config/runtime.exs` all other env vars; nothing read from env at compile time

## Rules

- `mix check` must pass (format, `--warnings-as-errors` compile and tests); CI (`.github/workflows/ci.yml`) runs it on pull requests.
- Keep `Dockerfile` (Debian) and `Dockerfile.alpine` in sync; `image.yml` publishes both to GHCR on `v*` tags.
- Tests never hit the network: upstream is stubbed via `Req.Test` (`config/test.exs`).
- Bump `@version` in `Prompt` whenever prompt text changes (it is part of the cache key).
- Sharkey reads `detectedLanguage.language` unconditionally; always return it (`"und"` fallback).
- API errors are always `{"error": "..."}`; the API endpoint has no session or socket.
- Secrets (API keys, OpenRouter key, admin password) are never logged or written to `settings.json`; the admin shows at most their last 4 characters.
- Never log note text.
- Keep code lean: no long comments or docs; only `README.md` and this file are documentation.
- `agents/` is gitignored scratch space (experiments, logs, Sharkey source in `agents/Sharkey-2025.4.7`).
- Prompt eval harness: `mix run agents/eval/run.exs prod [MODEL]`; findings in `agents/prompt-eval-notes.md`.
- Live testing uses the key in `~/.config/openrouter/key`; keep calls minimal.
