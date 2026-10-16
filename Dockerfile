ARG ELIXIR=1.20.4
ARG OTP=29.1.2
ARG DEBIAN=trixie-20261005-slim

FROM docker.io/hexpm/elixir:${ELIXIR}-erlang-${OTP}-debian-${DEBIAN} AS build

ENV MIX_ENV=prod
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

COPY lib lib
COPY config/runtime.exs config/
RUN mix release

FROM docker.io/debian:${DEBIAN}

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libstdc++6 libsctp1 openssl curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --home /app app

ENV LANG=C.UTF-8 LTP_PORT=5000
WORKDIR /app
COPY --from=build --chown=app /app/_build/prod/rel/lt_proxy ./
USER app

EXPOSE 5000
HEALTHCHECK CMD curl -fsS "http://localhost:${LTP_PORT}/health" || exit 1
CMD ["bin/lt_proxy", "start"]
