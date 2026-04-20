# Feedback relay (Option A)

Small **Node** service that verifies `Authorization: Bearer` against `RELAY_SECRET`, then creates a GitHub issue with `GITHUB_TOKEN` (server-side only).

Matches the FSDMXVision client: `POST` with JSON `{ title, body, repository, appVersion }`.

## Local run

```bash
cd scripts/feedback-relay
npm install
export RELAY_SECRET="$(openssl rand -hex 24)"
export GITHUB_TOKEN="ghp_..."   # PAT with Issues: write on the repo
npm start
```

In **Settings → Feedback relay URL** use:

`http://127.0.0.1:8080/`

Paste the same value as **Relay authorization** as you set in `RELAY_SECRET` (the app sends `Bearer <that value>`).

## Production

- Deploy this process behind **HTTPS** (Fly.io, Railway, Render, etc.).
- Set `RELAY_SECRET`, `GITHUB_TOKEN`, and `PORT` via the host’s env config.
- Use `https://your-domain/` as the relay URL in the app (plain `http` is only allowed for localhost in the client).

### Docker

From `scripts/feedback-relay/`:

```bash
docker build -t cosmic-feedback-relay .
docker run --rm -p 8080:8080 \
  -e RELAY_SECRET="$RELAY_SECRET" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e PORT=8080 \
  cosmic-feedback-relay
```

The image runs `node server.js` as a non-root user. Prefer a managed secret store for `GITHUB_TOKEN` in production.

### macOS app signing / notarization

Shipping the **desktop** app is separate from this relay. Maintainer steps (Developer ID, `notarytool`, stapling) are documented in the repo root [`docs/release-runbook.md`](../../docs/release-runbook.md) (Section K and following).

## Optional: lock repository server-side

To ignore spoofed `repository` from the client, change `server.js` to use a fixed `owner/repo` from env (e.g. `TARGET_REPOSITORY`) instead of `req.body.repository`.
