ARG ELIXIR=1.20.4
ARG OTP=29.1.2
ARG DEBIAN=trixie-20261005-slim

FROM docker.io/hexpm/elixir:${ELIXIR}-erlang-${OTP}-debian-${DEBIAN} AS build

ENV MIX_ENV=prod
WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/* \
 && mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile && mix assets.setup

COPY lib lib
COPY priv priv
COPY assets assets
RUN mix compile && mix assets.deploy

COPY config/runtime.exs config/
RUN mix release

FROM docker.io/debian:${DEBIAN}

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libstdc++6 libsctp1 openssl curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --home /app app \
 && mkdir -p /app/data && chown app /app/data

ENV LANG=C.UTF-8 LTP_ADMIN_BIND=0.0.0.0
WORKDIR /app
COPY --from=build --chown=app /app/_build/prod/rel/lt_proxy ./
USER app

VOLUME /app/data
EXPOSE 5000 5001
HEALTHCHECK CMD curl -fsS "http://localhost:${LTP_PORT:-5000}/health" || exit 1
CMD ["bin/lt_proxy", "start"]
