FROM alpine:3.7

ARG MIX_ENV
ENV MIX_ENV $MIX_ENV

RUN mkdir -p /do_storage /run/docker/plugins /mnt/state /mnt/volumes
WORKDIR /do_storage
ADD repositories /etc/apk/repositories
RUN apk add --no-cache elixir@edge erlang-crypto@edge erlang-parsetools@edge erlang-tools@edge erlang-syntax-tools@edge erlang-runtime-tools@edge
ADD mix.exs mix.lock ./
RUN mix local.hex --force && mix local.rebar --force && mix deps.get && mix deps.compile
ADD . .
RUN mix compile

ENTRYPOINT ["mix", "run", "--no-halt"]
