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


## Railway / WARP over IPv6 (MTU + TCP MSS clamp)

This image is built from a fork of opencode2api (branch `feat/warp-mtu`, `REPO` / `REF` /
`GIT_SHA` build args in the Dockerfile) that adds `warp.mtu`, `warp.tcp_mss`,
`warp.endpoint_port` and `warp.init_timeout_seconds`.

Railway's container network has a path MTU of 1316 (1300-byte packets pass, 1328 fail).
WireGuard adds 60-80 bytes, so full-size packets of a 1280-byte tunnel are dropped: the
handshake works, but TLS and large transfers stall and WARP initialization times out.

- IPv4 inside the tunnel: `"stack": "ipv4"`, `"mtu": 1200` works (measured).
- IPv6 inside the tunnel needs an MTU >= 1280, so `"tcp_mss": 1160` clamps the TCP MSS
  (like iptables TCPMSS --clamp) to keep outer packets <= 1316.

Current config: `"stack": "ipv6", "mtu": 1280, "tcp_mss": 1160`.
Fallback if it does not start: `"stack": "ipv4", "mtu": 1200, "tcp_mss": 0`.

At startup the entrypoint prints the effective WARP config and non-fatal network
diagnostics. Set `WARP_NETWORK_DIAGNOSTICS=0` in Railway Variables to disable them.

The container intentionally does not request `NET_ADMIN`, create a TUN device,
or change host routes.

## Decisive WARP diagnostic

Set `WARP_DIAG=1` in Railway Variables (optionally `WARP_DIAG_TIMEOUT=300s`) and redeploy.
Before starting the app, the entrypoint runs `warpdiag` (built from `cmd/warpdiag` in the
fork) and prints a report between `===== WARPDIAG START =====` and `===== WARPDIAG END =====`.
The diagnostic runs once per volume (marker `/data/.warpdiag_done`); use `WARP_DIAG=force` to run it again.
Remove the variable afterwards.
