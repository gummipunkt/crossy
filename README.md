# Crossy

![Crossy logo](https://github.com/gummipunkt/crossy/blob/main/server/app/assets/images/crossy_logo.svg)

A small Rails app that helps you post to multiple social networks at once. It started as a single‑user tool and is being built so it can grow into a multi‑user SaaS later.

Today it supports Mastodon, Bluesky and Threads. Nostr is on the way (the UI wiring is there; server‑side signing will follow).

## What it does

- A clean composer with file uploads and alt text
- Pick the networks you want (there’s a “Select all” button)
- Background deliveries with per‑provider status
- A unified timeline across your connected accounts (auto‑refresh, like/repost)
- Encrypted token storage (Lockbox + BlindIndex)
- Sign up and sign in (Devise)
- Multi-User mode
- Admin area to manage users (promote to admin, delete users)

## Screenshots

![Timeline](server/app/assets/samples/SCR-20251017-kanm.png)

![Composer](server/app/assets/samples/SCR-20251017-kcgi.png)

![Providers](server/app/assets/samples/SCR-20251017-kbon.png)

![Login](server/app/assets/samples/SCR-20251017-kbgb.jpeg)

## Tech

- Ruby 3.3, Rails 8
- PostgreSQL and Redis
- Solid Queue for background jobs
- Tailwind CSS, esbuild, Hotwire (Turbo, Stimulus)
- Faraday for HTTP calls
- Security: Devise, Rack::Attack, Secure Headers, Lockbox, BlindIndex
- Everything runs in Docker

## Development (Docker)

Requirements: Docker and Docker Compose.

1) Boot the stack

```bash
git clone https://github.com/yourname/crossy.git
cd crossy
docker compose up -d --build
```

2) Set up the database

```bash
docker compose exec -w /app/server web bash -lc "bin/rails db:create db:migrate"
```

3) Build frontend assets (first run)

```bash
docker compose exec -w /app/server web bash -lc "bin/rails javascript:install:esbuild || true; bin/rails css:install:tailwind || true; npm install; bin/rails javascript:build && bin/rails css:build"
```

4) Open the app

- http://localhost:3000
- Composer is the start page
- Unified timeline: `/timeline`
- Your own posts: `/my`
- Provider accounts: `/provider_accounts`

## Production (Docker)

Use the dedicated production compose file. Provide your secrets in `env/.env.production`.

1) Create `env/.env.production`

Minimal example:

```env
# Rails
RAILS_ENV=production
RACK_ENV=production
SECRET_KEY_BASE=<64+ char random secret>

# Base URL 
PUBLIC_BASE_URL=https://your-domain.example

# Logging/Proxy
RAILS_LOG_LEVEL=info
RAILS_LOG_TO_STDOUT=true
RAILS_FORCE_SSL=true
ACTION_DISPATCH_TRUSTED_PROXIES=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1,::1

# Database
# Für Managed-Postgres: setze sslmode=require
DATABASE_URL=postgres://user:pass@host:5432/dbname?sslmode=require
# Optional: zusätzliche Verbindungen
# CACHE_DATABASE_URL=...
# QUEUE_DATABASE_URL=...
# CABLE_DATABASE_URL=...
# DB_POOL=5
# DB_SSLMODE=require
# DB_CONNECT_TIMEOUT=5
# DB_REAPING_FREQUENCY=10
# DB_PREPARED_STATEMENTS=true

# Secrets für Verschlüsselung
# LOCKBOX_MASTER_KEY: 64 Hex-Zeichen (z. B. mit `ruby -e 'require "securerandom"; puts SecureRandom.hex(32)'`)
LOCKBOX_MASTER_KEY=<64hex>
# BLIND_INDEX_MASTER_KEY: exakt 64 Hex-Zeichen (immer in Anführungszeichen lassen)
BLIND_INDEX_MASTER_KEY="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

# SMTP (Passwort-Reset)
SMTP_ADDRESS=smtp.your-domain.example
SMTP_PORT=587
SMTP_DOMAIN=your-domain.example
SMTP_USERNAME=your-user
SMTP_PASSWORD=your-pass
SMTP_AUTH=login
SMTP_STARTTLS=true

# Provider
# Threads: verwende die Domain threads.net (nicht threads.com)
THREADS_APP_ID=...
THREADS_APP_SECRET=...
THREADS_CLIENT_TOKEN=...
THREADS_GRAPH_BASE=https://graph.threads.net
THREADS_OAUTH_BASE=https://www.threads.net

# Bluesky
BLUESKY_BASE=https://bsky.social
```

2) Boot production

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

3) Logs

```bash
docker compose -f docker-compose.prod.yml logs -f web
```

Notes:
- The production compose includes a local Postgres service for convenience. For managed Postgres, set `DATABASE_URL` and remove/ignore the `db` service.
- It runs `db:prepare`, builds JS/CSS, and precompiles assets on startup. Healthcheck probes `GET /up`.
- Default publish is `3022:3000`. Put a reverse proxy (Caddy/Nginx) in front or change the port mapping.
- Persistent volumes store gems and uploads: `bundle-data`, `storage`.

## Configuration

Environment variables can be provided either via `docker-compose.yml`/`docker-compose.prod.yml` or an env file. Recommended:

- Development: use `docker compose` as shown above; defaults are set in `docker-compose.yml`. Optional: `.env` (see `.env.example`).
- Production: use `docker-compose.prod.yml` with `env/.env.production` (see `env/.env.production.example`).

Set these variables:

- Lockbox / BlindIndex
  - `LOCKBOX_MASTER_KEY`
  - `BLIND_INDEX_MASTER_KEY` (64 hex chars). Quote it in YAML: "abcdef..."
- Threads API
  - `THREADS_APP_ID`
  - `THREADS_APP_SECRET`
  - `THREADS_CLIENT_TOKEN`
  - `PUBLIC_BASE_URL` (used for OAuth redirects, mailer links, public asset URLs)
  - `THREADS_GRAPH_BASE` (optional; defaults to `https://graph.threads.net`)
  - `THREADS_OAUTH_BASE` (optional; defaults to `https://www.threads.net`)

Threads prerequisites
- In deiner Threads-/Meta‑App die Redirect‑URI exakt whitelisten: `https://<your-domain>/auth/threads/callback`
- App‑ID und Secret in `env/.env.production` setzen
- Bei Problemen sicherstellen, dass die OAuth‑URL auf `threads.net` zeigt (nicht `.com`)

- SMTP (password reset emails)
  - `MAILER_SENDER`
  - `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `SMTP_USERNAME`, `SMTP_PASSWORD`
  - `SMTP_AUTH` (login/plain), `SMTP_STARTTLS` (true/false), `SMTP_OPENSSL_VERIFY_MODE` (optional)

- Database
  - `DATABASE_URL` (required in production)
  - `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, `CABLE_DATABASE_URL` (optional; fall back to `DATABASE_URL`)
  - `DB_POOL`, `DB_SSLMODE`, `DB_CONNECT_TIMEOUT`, `DB_REAPING_FREQUENCY`, `DB_PREPARED_STATEMENTS` (optional tuning)

- Bluesky
  - `BLUESKY_BASE` (optional; defaults to `https://bsky.social`)

Examples: see `env/.env.production.example` and `.env.example`.

If you change env, recreate the containers:

```bash
docker compose down && docker compose up -d --force-recreate --build
```

## Connecting providers

Mastodon
- Add your instance (full https URL) and a token under Provider Accounts
- Token scopes should include `write:statuses` and `write:media`

Bluesky
- Add your handle under Provider Accounts
- Create an app password in Bluesky
- Save the refresh token once:

```bash
docker compose exec -w /app/server web bash -lc "bin/rails runner 'pa=ProviderAccount.where(provider: \"bluesky\").first; Posting::BlueskyClient.new(pa).login!(ENV.fetch(\"BSKY_APP_PASSWORD\"))'"
```

Threads
- Use “Connect Threads” (`/auth/threads`) to store a long‑lived token

Nostr (preview)
- Buttons on the post page let you prepare/sign/publish with a NIP‑07 browser extension

## Using it

- Write your post, attach media, add alt text (one per line)
- Select networks (or click “Select all”)
- Submit and watch delivery status per provider
- Use `/timeline` to see all connected feeds in one place; like/repost from there

## Troubleshooting

Assets fail to build
- If you see `esbuild: not found`, run the install/build step from Quick start
- Do a hard reload in the browser after building

Images don’t render
- Make sure your CSP allows remote images. This app configures Secure Headers to permit `https:`/`http:` for `img_src`.

Threads token expired (code 190)
- Reconnect at `/auth/threads`, then reload `/timeline`

Mastodon media upload fails
- Check scopes and that your instance URL starts with `https://`

Gems get reinstalled every boot
- Keep the bundle volume enabled in `docker-compose.yml`

## Security notes

- Secrets stay in env
- Access/refresh tokens are encrypted at rest
- Basic rate limiting and sensible headers are enabled

## Roadmap

- Nostr server‑side session signing
- Provider webhooks/streaming
- Better media support (video, carousels)
- Threads support for timeline
- User Profile Management Page

## License

Licensed under EUPL v1.2. See the official text: https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12


