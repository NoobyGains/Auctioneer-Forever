FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      lua5.1 liblua5.1-0-dev luarocks build-essential ca-certificates git unzip \
  && rm -rf /var/lib/apt/lists/*
RUN luarocks --lua-version=5.1 install busted 2.2.0-1
WORKDIR /src
ENTRYPOINT ["busted"]
