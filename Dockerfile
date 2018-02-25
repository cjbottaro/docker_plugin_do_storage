FROM alpine:3.7

RUN mkdir -p /do_storage /run/docker/plugins /mnt/state /mnt/volumes
WORKDIR /do_storage
ADD . .
RUN mv repositories /etc/apk/repositories && apk add --no-cache elixir@edge erlang-crypto@edge erlang-parsetools@edge erlang-tools@edge erlang-syntax-tools@edge erlang-runtime-tools@edge
RUN mix local.hex --force && mix local.rebar --force && mix deps.get && mix deps.compile && mix compile

ENTRYPOINT ["mix", "run", "--no-halt"]
