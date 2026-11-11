# zenmood

## Run locally

```sh
cp .env.example .env
# Set your secret API_KEY in .env
docker compose up -d --build
```

The default local API base URL is `http://localhost:8080/v1`.

## Use the API

Set your client’s base URL to `https://<your-domain>/v1` when accessing zenmood externally. Authenticate with `Authorization: Bearer <API_KEY>` or `x-api-key: <API_KEY>`.

List available models:

```sh
set -a
. ./.env
set +a
curl http://localhost:8080/v1/models \
  -H "Authorization: Bearer $API_KEY"
```

Test the deployed API (replace the example host with your public domain; set `API_KEY` in your shell):

```sh
curl -fsS https://your-domain.example/v1/models \
  -H "Authorization: Bearer $API_KEY"
```

Main endpoints: `GET /v1/models`, `POST /v1/chat/completions`, `POST /v1/responses`, and `POST /v1/messages`. The unauthenticated health endpoint is `GET /healthz`.


## Railway / WARP MTU

This image is built from a fork of opencode2api that adds a `warp.mtu` option
(branch `feat/warp-mtu`, set by the `REPO` / `REF` build args in the Dockerfile).

Railway's container network has an MTU of 1316 (measured path MTU: 1300-byte
packets pass, 1328-byte packets fail). A WireGuard tunnel at the default MTU of
1280 adds ~60-80 bytes of overhead and exceeds that limit, so WARP initialization
timed out on the `/cdn-cgi/trace` verification even though registration and plain
UDP worked. `config.json` therefore sets `"mtu": 1200`.

If WARP initialization still fails, try in `config.json`:

- a lower `warp.mtu` (e.g. 1100), or
- `"stack": "ipv4"`.

At startup the entrypoint prints the effective WARP config and non-fatal network
diagnostics (IPv4/IPv6 egress, UDP, path-MTU pings) to the logs. Set
`WARP_NETWORK_DIAGNOSTICS=0` in Railway Variables to disable the diagnostics once
everything works.

The container intentionally does not request `NET_ADMIN`, create a TUN device,
or change host routes.

## Decisive WARP diagnostic

Set `WARP_DIAG=1` in Railway Variables (optionally `WARP_DIAG_TIMEOUT=300s`) and redeploy.
Before starting the app, the entrypoint runs `warpdiag` (built from `cmd/warpdiag` in the
fork) and prints a report between `===== WARPDIAG START =====` and `===== WARPDIAG END =====`.
The diagnostic runs once per volume (marker `/data/.warpdiag_done`); use `WARP_DIAG=force` to run it again.
Remove the variable afterwards.
