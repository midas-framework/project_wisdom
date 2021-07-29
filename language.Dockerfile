FROM rust:1.53.0 AS build

ENV SHA="39db5f59df41f7e61aefa1971c910c21b082725e"
RUN set -xe \
        && curl -fSL -o gleam-src.tar.gz "https://github.com/gleam-lang/gleam/archive/${SHA}.tar.gz" \
        && mkdir -p /usr/src/gleam-src \
        && tar -xzf gleam-src.tar.gz -C /usr/src/gleam-src --strip-components=1 \
        && rm gleam-src.tar.gz \
        && cd /usr/src/gleam-src \
        && make install \
        && rm -rf /usr/src/gleam-src 

WORKDIR /opt/app
RUN cargo install watchexec-cli

FROM elixir:1.12.2
# FROM node:16.5.0

COPY --from=build /usr/local/cargo/bin/gleam /bin
RUN gleam --version

CMD ["gleam"]