# Crossy

![Crossy logo](server/app/assets/images/crossy_logo.svg)

A small Rails app that helps you post to multiple social networks at once. It started as a single-user tool and is being built so it can grow into a multi-user SaaS later.

**Networks:** Mastodon, Bluesky, Threads, and **Nostr** (compose/sign/publish via **NIP-07** in the browser; relays are configured in code).

## What it does

- Composer with file uploads and alt text
- Pick the networks you want (including “Select all”)
- Background deliveries with per-provider status
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
- Redis (started by the example Docker Compose file; the app does not use it yet)
- Solid Queue for background jobs (database-backed in the default configuration)
- Tailwind CSS, esbuild, Hotwire (Turbo, Stimulus)
- Faraday for HTTP calls
- Security: Devise, Rack::Attack, Secure Headers, Lockbox, Blind Index, SSRF checks on user-supplied instance URLs

## Run with Docker Compose

The repo ships an example compose file: [`docker-compose.prod.yml.example`](docker-compose.prod.yml.example). Copy it to `docker-compose.yml` (which is gitignored) and adjust it. It runs Rails in **production** mode with a source bind mount (good for local iteration), bundled **web** and **worker** services, Postgres, and Redis.

**Requirements:** Docker and Docker Compose.

### 1. Clone and configure

```bash
git clone https://github.com/gummipunkt/crossy.git
cd crossy
cp docker-compose.prod.yml.example docker-compose.yml
cp env/.env.production.example env/.env.production
# Fill in env/.env.production: SECRET_KEY_BASE, LOCKBOX_MASTER_KEY, BLIND_INDEX_MASTER_KEY,
# PUBLIC_BASE_URL, SMTP, Threads keys, etc.
```

Generate the secrets instead of reusing example values:

```bash
openssl rand -hex 64   # SECRET_KEY_BASE
openssl rand -hex 32   # LOCKBOX_MASTER_KEY
openssl rand -hex 32   # BLIND_INDEX_MASTER_KEY
```

Back up `LOCKBOX_MASTER_KEY`: without it the stored access tokens cannot be decrypted.

The example compose file uses `crossy:crossy` as database credentials, both for the `db` service and in the `DATABASE_URL`/`*_DATABASE_URL` entries of `web` and `worker`. Change them in all places if the database is reachable from outside.

### 2. Start the stack

```bash
docker compose up -d --build
```

The **web** container runs `db:prepare`, builds JS/CSS, precompiles assets, then starts Puma on port **3000** inside the container.

### 3. Open the app

- **From your machine:** [http://localhost:3022](http://localhost:3022) (host port **3022** is mapped to container port 3000)
- Health check: `GET /up`
- Root / composer: `/`
- Timeline: `/timeline`
- Your posts: `/my`
- Provider accounts: `/provider_accounts`

### First-time / manual asset build (if needed)

If assets are missing:

```bash
docker compose exec -w /app/server web bash -lc "bin/rails javascript:build && bin/rails css:build && bin/rails assets:precompile"
```

### Database migrations (if you run commands yourself)

```bash
docker compose exec -w /app/server web bash -lc "bin/rails db:migrate"
```

## Configuration

Environment variables are loaded from **`env/.env.production`** (see [`env/.env.production.example`](env/.env.production.example)). For local development see [`.env.development.example`](.env.development.example).

**Important**

- **`PUBLIC_BASE_URL`** — OAuth redirects, mailer links, host authorization (with `localhost` / `127.0.0.1` allowed for internal checks where configured).
- **Threads** — Whitelist redirect URI: `https://<your-domain>/auth/threads/callback`. Use **threads.net** OAuth/Graph URLs, not **threads.com**. The Meta app needs the permissions `threads_basic`, `threads_content_publish`, `threads_manage_insights` and `threads_read_replies` (the last two for likes/replies/reposts); override with `THREADS_SCOPES` if needed. Tokens are refreshed daily by a recurring job; an account whose token can no longer be refreshed is marked for reconnecting.
- **Lockbox / Blind Index** — `LOCKBOX_MASTER_KEY`, `BLIND_INDEX_MASTER_KEY` (64 hex characters each).

**SMTP (password reset):** `MAILER_SENDER`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTH`, `SMTP_STARTTLS`, optional `SMTP_OPENSSL_VERIFY_MODE`.

**Database:** `DATABASE_URL` required in production; optional `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, `CABLE_DATABASE_URL` (Compose sets separate DB URLs by default). Tuning: `DB_POOL`, `DB_SSLMODE`, `DB_CONNECT_TIMEOUT`, etc.

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

- **Assets / esbuild** — Run the asset build commands above inside the `web` container; hard-reload the browser.
- **Images blocked** — CSP is configured in Secure Headers; remote timeline images use broad `img_src` for provider CDNs.
- **Threads token (e.g. 190)** — Reconnect via `/auth/threads`.
- **Mastodon uploads** — Check token scopes and that the instance URL uses `https://`.
- **Gems reinstalling every boot** — Normal if the container is recreated without a persistent bundle volume; Compose uses a `bundle-data` volume to cache gems between restarts.

## Security notes

- Keep secrets in environment or a secrets manager, not in git.
- Access tokens are encrypted at rest (Lockbox).
- Rate limiting (Rack::Attack) and security headers are enabled; user-supplied federation URLs are validated before server-side HTTP requests.

## Roadmap (ideas)

- Richer Nostr relay configuration (UI / per account)
- Provider webhooks / streaming
- Better media (video, carousels)
- Profile management

## License

Licensed under **EUPL-1.2**. Official text: [EUPL-1.2](https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12)
