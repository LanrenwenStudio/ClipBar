# ClipBar quota backend

A tiny standard-library Python service for a soft-router Docker host. It polls
CLIProxyAPI every 10 minutes, keeps the last successful snapshot on disk, and
serves that snapshot to ClipBar clients.

## Run with Docker Compose

```bash
cd backend
cp .env.example .env
# edit .env; use a long random CLIPBAR_ACCESS_TOKEN
docker compose up -d --build
curl http://127.0.0.1:8080/healthz
curl -H "Authorization: Bearer $CLIPBAR_ACCESS_TOKEN" \
  http://127.0.0.1:8080/v1/snapshot
```

The `data/snapshot.json` file is the durable cache. A failed poll keeps the last
successful `accounts` array and only updates `error` and `last_attempt_at`.
The service intentionally does not expose CLIProxyAPI's management key.

On a router where CLIProxyAPI runs outside Docker, set `CLIPROXY_BASE_URL` to
the router LAN address instead of `host.docker.internal`.

## API

- `GET /healthz` — unauthenticated process and poll status.
- `GET /v1/snapshot` — requires `Authorization: Bearer $CLIPBAR_ACCESS_TOKEN`.
- `POST /v1/refresh` — authenticated immediate poll, then returns the new snapshot.
- `GET /v1/settings` — returns the shared refresh interval.
- `PUT /v1/settings` — updates the shared refresh interval and wakes the poller.

The shared interval accepts the same presets as the apps: 60, 180, 300, 600,
or 900 seconds. It is persisted in `/data/settings.json`, so macOS and iOS
read and write the same value.

The snapshot `accounts` entries use the same JSON shape as ClipBar's
`AccountQuota` model (`account` plus `snapshot`), so the app can decode it
without reimplementing provider parsing.

## Security

Keep port `8080` on the LAN/VPN only. If the endpoint is exposed beyond a
trusted network, put it behind HTTPS/reverse-proxy authentication; the built-in
token is intentionally simple and does not provide user management or TLS.
