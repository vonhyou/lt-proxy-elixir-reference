# AGENTS.md

LibreTranslate-compatible proxy to an LLM on OpenRouter, for Sharkey/Misskey. Elixir 1.20, OTP 29, Plug + Bandit, Req, Cachex.

## Layout

- `lib/lt_proxy/translate/` pure modules: `Lang`, `Request`, `Prompt`, `Output`
- `lib/lt_proxy/upstream.ex` OpenRouter client; `translator.ex` cache → slot → upstream → parse
- `lib/lt_proxy/cache.ex` (Cachex, dedupes concurrent loads, never caches errors), `slots.ex` (atomics concurrency cap), `rate_limit.ex` (optional ETS RPM)
- `lib/lt_proxy/web/router.ex` HTTP API and error mapping
- `config/runtime.exs` all env vars; nothing read from env at compile time

## Rules

- `mix check` must pass (format, `--warnings-as-errors` compile and tests).
- Tests never hit the network: upstream is stubbed via `Req.Test` (`config/test.exs`).
- Bump `@version` in `Prompt` whenever prompt text changes (it is part of the cache key).
- Sharkey reads `detectedLanguage.language` unconditionally; always return it (`"und"` fallback).
- Never log note text or the OpenRouter key.
- Keep code lean: no long comments or docs; only `README.md` and this file are documentation.
- `agents/` is gitignored scratch space (experiments, logs, Sharkey source in `agents/Sharkey-2025.4.7`).
- Prompt eval harness: `mix run agents/eval/run.exs prod [MODEL]`; findings in `agents/prompt-eval-notes.md`.
- Live testing uses the key in `~/.config/openrouter/key`; keep calls minimal.
