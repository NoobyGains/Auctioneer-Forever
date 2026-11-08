#!/bin/sh
# Runs the specs with busted inside one long-lived container (docker exec), so a run
# neither creates nor removes a container.
# ponytail: the image is built only when missing; after editing spec/Dockerfile run
# `docker rmi -f auctioneer-spec; docker rm -f auctioneer-spec-runner` once to rebuild.
set -e
cd "$(dirname "$0")/.."
docker image inspect auctioneer-spec >/dev/null 2>&1 || docker build -q -t auctioneer-spec spec >/dev/null
if [ "$(docker inspect -f '{{.State.Running}}' auctioneer-spec-runner 2>/dev/null)" != "true" ]; then
	docker rm -f auctioneer-spec-runner >/dev/null 2>&1 || true
	docker run -d --name auctioneer-spec-runner -v "$PWD":/src --entrypoint sleep auctioneer-spec infinity >/dev/null
fi
exec docker exec -w /src auctioneer-spec-runner timeout 120 busted "$@"
