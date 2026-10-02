# Crossy

![Crossy logo](server/app/assets/images/crossy_logo.svg)

A small Rails app that helps you post to multiple social networks at once. It started as a single-user tool and is being built so it can grow into a multi-user SaaS later.

**Networks:** Mastodon, Bluesky, Threads, and **Nostr** (compose/sign/publish via **NIP-07** in the browser; relays are configured in code).

## What it does

- Composer with file uploads and alt text
- Pick the networks you want (including “Select all”)
- Background deliveries with per-provider status; failed deliveries can be retried
- Scheduled posts (dispatched by a recurring job every minute; "Publish now" / "Cancel" on the post page)
- Unified timeline across connected accounts (auto-refresh, like/repost)
- Encrypted token storage (Lockbox + Blind Index)
- Sign up / sign in (Devise)
- Multi-user mode with an admin area (promote admins, manage users)

## Screenshots

![Timeline](server/app/assets/samples/SCR-20251017-kanm.png)

![Composer](server/app/assets/samples/SCR-20251017-kcgi.png)

![Providers](server/app/assets/samples/SCR-20251017-kbon.png)

![Login](server/app/assets/samples/SCR-20251017-kbgb.jpeg)

## Tech

- Ruby 3.3, Rails 8.1
- PostgreSQL (app plus separate DBs for Solid Cache, Solid Queue, Solid Cable in the default Docker setup)
- Solid Queue for background jobs (database-backed in the default configuration)
- Tailwind CSS, esbuild, Hotwire (Turbo, Stimulus)
- Faraday for HTTP calls
- Security: Devise, Rack::Attack, Secure Headers, Lockbox, Blind Index, SSRF checks on user-supplied instance URLs

## Run with Docker Compose

The repo ships an example compose file: [`docker-compose.prod.yml.example`](docker-compose.prod.yml.example). Copy it to `docker-compose.yml` (which is gitignored) and adjust it. It builds a production image from [`server/Dockerfile`](server/Dockerfile) (gems and assets are baked in at build time, the app runs as an unprivileged user) and runs a **web** and a **worker** container from it, plus Postgres.

**Requirements:** Docker and Docker Compose, and a TLS-terminating reverse proxy (Caddy, nginx, Traefik, ...) in front of the app: production forces HTTPS.

### 1. Clone and configure

```bash
git clone https://github.com/gummipunkt/crossy.git
cd crossy
cp docker-compose.prod.yml.example docker-compose.yml
echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)" > .env
cp env/.env.production.example env/.env.production
# Fill in env/.env.production: SECRET_KEY_BASE, LOCKBOX_MASTER_KEY, BLIND_INDEX_MASTER_KEY,
# PUBLIC_BASE_URL, SMTP, Threads keys, etc.
```

`.env` (next to `docker-compose.yml`, gitignored) only holds `POSTGRES_PASSWORD`; compose uses it for the database and builds the `DATABASE_URL`s from it. Leave `DATABASE_URL` out of `env/.env.production`.

Generate the secrets instead of reusing example values:

```bash
openssl rand -hex 64   # SECRET_KEY_BASE
openssl rand -hex 32   # LOCKBOX_MASTER_KEY
openssl rand -hex 32   # BLIND_INDEX_MASTER_KEY
```

Back up `LOCKBOX_MASTER_KEY`: without it the stored access tokens cannot be decrypted.

### 2. Start the stack

```bash
docker compose up -d --build
```

The **web** container runs `db:prepare` (creates/migrates all databases) and starts Puma behind Thruster. The **worker** starts once web is healthy and runs Solid Queue, including the recurring jobs (scheduled posts every minute, daily Threads token refresh).

After pulling a new version, run `docker compose up -d --build` again; migrations run automatically.

### 3. Open the app

The app listens on **127.0.0.1:3022** only (change with `CROSSY_PORT` in `.env`). Point your reverse proxy at it; the health check is `GET /up`.

- Root / composer: `/`
- Timeline: `/timeline`
- Your posts: `/my`
- Provider accounts: `/provider_accounts`

### Running commands

```bash
docker compose exec web bin/rails console
docker compose exec web bin/rails db:migrate
```

### Upgrading from the old compose file (source bind mount, Redis)

Earlier versions ran the app as root from a bind-mounted checkout. To switch:

1. Replace your `docker-compose.yml` with the new example. The volume names `db-data` and `storage` are unchanged, so data is kept. The old `redis-data` and `bundle-data` volumes are no longer used (`docker volume rm` them if you like).
2. The existing database was initialised with the password `crossy`. Either put `POSTGRES_PASSWORD=crossy` into `.env`, or change it first:
   `docker compose exec db psql -U crossy -d server_production -c "ALTER USER crossy PASSWORD 'new-secret'"` and use that value.
3. Remove `DATABASE_URL` from `env/.env.production` if you set it there.
4. Uploaded files were written as root; give them to the app user once:
   `docker compose run --rm --user root web chown -R 1000:1000 /rails/storage`
5. Update your reverse proxy to `127.0.0.1:3022` (unchanged port, now bound to localhost only).

## Configuration

Environment variables are loaded from **`env/.env.production`** (see [`env/.env.production.example`](env/.env.production.example)). For local development see [`.env.development.example`](.env.development.example).

**Important**

- **`PUBLIC_BASE_URL`** — OAuth redirects, mailer links, host authorization (with `localhost` / `127.0.0.1` allowed for internal checks where configured).
- **Threads** — Whitelist redirect URI: `https://<your-domain>/auth/threads/callback`. Use **threads.net** OAuth/Graph URLs, not **threads.com**. The Meta app needs the permissions `threads_basic`, `threads_content_publish`, `threads_manage_insights` and `threads_read_replies` (the last two for likes/replies/reposts); override with `THREADS_SCOPES` if needed. Tokens are refreshed daily by a recurring job; an account whose token can no longer be refreshed is marked for reconnecting.
- **Lockbox / Blind Index** — `LOCKBOX_MASTER_KEY`, `BLIND_INDEX_MASTER_KEY` (64 hex characters each).

**SMTP (password reset):** `MAILER_SENDER`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTH`, `SMTP_STARTTLS`, optional `SMTP_OPENSSL_VERIFY_MODE`.

**Database:** `DATABASE_URL` required in production; optional `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, `CABLE_DATABASE_URL` (the compose file sets all four from `POSTGRES_PASSWORD`). Tuning: `DB_POOL`, `DB_SSLMODE`, `DB_CONNECT_TIMEOUT`, etc.

**Bluesky:** optional `BLUESKY_BASE` (default `https://bsky.social`). Connect via **Provider accounts** in the UI (handle + app password).

After changing env:

```bash
docker compose down && docker compose up -d --force-recreate
```

## Local development without Docker (optional)

If you have Ruby/Node/Postgres locally:

```bash
cd server
bundle install
bin/rails db:prepare
bin/dev
```

Use `config/database.yml` and env vars as usual for development.

## Connecting providers

- **Mastodon** — Instance URL (https) + access token; scopes must include `write:statuses` (or `write`), plus `write:media` if you upload.
- **Bluesky** — Handle + app password under Provider accounts. Posts are limited to 300 characters and up to 4 images of at most ~1 MB each; links, mentions and hashtags become clickable.
- **Threads** — “Connect Threads” → `/auth/threads`.
- **Nostr** — Add a Nostr provider account with its public key in hex (not `npub`); on the post page use sign / publish with a **NIP-07** extension. The server verifies the signed event and only marks it published when a relay accepts it.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs Brakeman, bundler-audit, RuboCop, and tests from the **`server/`** directory.

## Troubleshooting

- **Assets missing / outdated** — Assets are built into the image; rebuild with `docker compose up -d --build` and hard-reload the browser.
- **Uploads fail with "Permission denied"** — Files in the `storage` volume must belong to uid 1000; see the upgrade steps above.
- **Images blocked** — CSP is configured in Secure Headers; remote timeline images use broad `img_src` for provider CDNs.
- **Threads token (e.g. 190)** — Reconnect via `/auth/threads`.
- **Mastodon uploads** — Check token scopes and that the instance URL uses `https://`.

## Security notes

- Keep secrets in environment or a secrets manager, not in git.
- Access tokens are encrypted at rest (Lockbox).
- Rate limiting (Rack::Attack) and security headers are enabled; user-supplied federation URLs are validated before server-side HTTP requests, and each connection is pinned to the validated IP address (protects against DNS rebinding; not effective behind an outbound HTTP proxy).

## Roadmap (ideas)

- Richer Nostr relay configuration (UI / per account)
- Provider webhooks / streaming
- Better media (video, carousels)
- Profile management

## License

Licensed under **EUPL-1.2**. Official text: [EUPL-1.2](https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12)
