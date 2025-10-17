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
RAILS_ENV=production
RACK_ENV=production
PUBLIC_BASE_URL=https://your-domain.example
MAILER_SENDER=Crossy <no-reply@your-domain.example>

# Database (managed Postgres)
DATABASE_URL=postgres://user:pass@host:5432/dbname?sslmode=require

# Locks/indices
LOCKBOX_MASTER_KEY=0000...64hex...
BLIND_INDEX_MASTER_KEY="1111...64hex..."  # keep quoted

# SMTP
SMTP_ADDRESS=smtp.your-domain.example
SMTP_PORT=587
SMTP_DOMAIN=your-domain.example
SMTP_USERNAME=your-user
SMTP_PASSWORD=your-pass
SMTP_AUTH=login
SMTP_STARTTLS=true

# Providers
THREADS_APP_ID=...
THREADS_APP_SECRET=...
THREADS_CLIENT_TOKEN=...
BLUESKY_BASE=https://bsky.social
THREADS_GRAPH_BASE=https://graph.threads.net
THREADS_OAUTH_BASE=https://www.threads.net
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
- The production compose runs `db:migrate`, builds JS/CSS, and precompiles assets on startup.
- Put a reverse proxy (Caddy/Nginx) in front of port 3000, or adjust the published port.
- Persistent volumes store gems and uploads: `bundle-data`, `storage`.

## Configuration

Environment variables can be provided either via `docker-compose.yml`/`docker-compose.prod.yml` or an env file. Recommended:

- Development: use `docker compose` as shown above; defaults are set in `docker-compose.yml`. Optionally create `.env` (see `.env.example`).
- Production: use `docker-compose.prod.yml` with `env/.env.production`.

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


