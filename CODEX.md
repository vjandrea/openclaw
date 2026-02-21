# Codex Baseline (2026-02-17)

## Current Setup Summary
- Deployment uses Docker Compose in `/home/ubuntu/dev/openclaw`.
- `openclaw-gateway` runs inside Docker and is reachable from the CLI container.
- Tailscale Serve is configured on the host to expose the gateway UI to the tailnet.
- Gateway bind is set to `lan` (0.0.0.0), with auth + rate limiting enabled.

## Important Paths & Configs
- Host config: `~/.openclaw/openclaw.json`
- CLI container config: `~/.openclaw/openclaw.cli.json` (set via `OPENCLAW_CONFIG_PATH` in `docker-compose.yml`)
- Sessions store: `/home/node/.openclaw/agents/main/sessions/sessions.json`
- Backups created during cleanup:
  - `/home/node/.openclaw/openclaw.cli.json.bak`
  - `/home/node/.openclaw/agents/main/sessions/sessions.json.bak2`

## Docker Compose Adjustments
- `openclaw-cli` environment includes:
  - `OPENCLAW_CONFIG_PATH=/home/node/.openclaw/openclaw.cli.json`
  - `OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}`
- Removed unused `OPENCLAW_GATEWAY_URL` from `openclaw-cli` service.

## Tailscale Serve
- Serve enabled on host for gateway UI:
  - `tailscale serve --bg 18789`
  - Status shows tailnet-only HTTPS URL proxying `http://127.0.0.1:18789`.
- `tailscaled` is enabled and running at boot (`systemctl is-enabled tailscaled` => enabled).

## Gateway Auth & Rate Limiting
- `gateway.auth.rateLimit` configured:
  - `maxAttempts: 10`, `windowMs: 60000`, `lockoutMs: 300000`
- Auth lockout can be cleared by restarting the gateway container.

## Doctor / Security Audit Findings
- `openclaw doctor` now shows no missing transcripts after cleanup.
- Remaining expected warnings:
  - Gateway bound to `lan` (network-accessible).
  - Skills missing requirements.
- `openclaw security audit --deep` flagged Dropbox skill patterns as potential exfiltration; review found they are expected OAuth/token + API calls.

## Session Cleanup Performed
- Orphaned session entries removed from `sessions.json`:
  - `4779efb8-9341-4714-910a-6e178eee1ede`
  - `a9de1069-49b6-45cf-973f-8f6f971e605a`
  - `cecaef5f-f97c-4d47-927a-c1d4bbe608b0`
  - `e60788ba-f210-4c28-b94c-5c29c15f212f`
- Current sessions list count: 2 entries.

## Device Pairing (Web UI)
- If Control UI shows `pairing required`, approve pending device requests:
  - `docker compose -f /home/ubuntu/dev/openclaw/docker-compose.yml run --rm openclaw-cli devices list`
  - `docker compose -f /home/ubuntu/dev/openclaw/docker-compose.yml run --rm openclaw-cli devices approve <requestId>`

## Commands Used Often
- Restart gateway: `docker compose -f /home/ubuntu/dev/openclaw/docker-compose.yml restart openclaw-gateway`
- Restart CLI: `docker compose -f /home/ubuntu/dev/openclaw/docker-compose.yml restart openclaw-cli`
- Check status: `docker compose -f /home/ubuntu/dev/openclaw/docker-compose.yml run --rm openclaw-cli status --json`
- Doctor: `docker compose -f /home/ubuntu/dev/openclaw/docker-compose.yml run --rm openclaw-cli doctor`
- Logs (follow): `docker compose -f /home/ubuntu/dev/openclaw/docker-compose.yml run --rm openclaw-cli logs --follow`

## Notes
- Do not store or paste the gateway auth token here.
- Tailscale Serve remains active across reboots as long as `tailscaled` stays enabled.
