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
