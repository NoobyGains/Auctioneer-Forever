#!/bin/sh
set -e
cd "$(dirname "$0")/.."
docker build -q -t auctioneer-spec spec >/dev/null
docker run --rm -v "$PWD":/src auctioneer-spec "$@"
