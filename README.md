# Crossy

A small Rails app that helps you post to multiple social networks at once. It started as a single‑user tool and is being built so it can grow into a multi‑user SaaS later.

Today it supports Mastodon, Bluesky and Threads. Nostr is on the way (the UI wiring is there; server‑side signing will follow).

## What it does

- A clean composer with file uploads and alt text
- Pick the networks you want (there’s a “Select all” button)
- Background deliveries with per‑provider status
- A unified timeline across your connected accounts (auto‑refresh, like/repost)
- Encrypted token storage (Lockbox + BlindIndex)

## Tech

- Ruby 3.3, Rails 8
- PostgreSQL and Redis
- Solid Queue for background jobs
- Tailwind CSS, esbuild, Hotwire (Turbo, Stimulus)
- Faraday for HTTP calls
- Security: Devise, Rack::Attack, Secure Headers, Lockbox, BlindIndex
- Everything runs in Docker

## Quick start (Docker)

Requirements: Docker and Docker Compose.

1) Boot the stack

```bash
git clone https://github.com/yourname/crossy.git
cd crossy
docker-compose up -d --build
```

2) Set up the database

```bash
docker-compose exec -w /app/server web bash -lc "bin/rails db:create db:migrate"
```

3) Build frontend assets (first run)

```bash
docker-compose exec -w /app/server web bash -lc "bin/rails javascript:install:esbuild || true; bin/rails css:install:tailwind || true; npm install; bin/rails javascript:build && bin/rails css:build"
```

4) Open the app

- http://localhost:3000
- Composer is the start page
- Unified timeline: `/timeline`
- Your own posts: `/my`
- Provider accounts: `/provider_accounts`

## Configuration

Environment variables are managed in `docker-compose.yml`. Set these before you start:

- Lockbox / BlindIndex
  - `LOCKBOX_MASTER_KEY`
  - `BLIND_INDEX_MASTER_KEY` (64 hex chars). Quote it in YAML: "abcdef..."
- Threads API
  - `THREADS_APP_ID`
  - `THREADS_APP_SECRET`
  - `THREADS_CLIENT_TOKEN`
  - `PUBLIC_BASE_URL` (used for public asset URLs)

If you change env, recreate the containers:

```bash
docker-compose down && docker-compose up -d --force-recreate --build
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
docker-compose exec -w /app/server web bash -lc "bin/rails runner 'pa=ProviderAccount.where(provider: \"bluesky\").first; Posting::BlueskyClient.new(pa).login!(ENV.fetch(\"BSKY_APP_PASSWORD\"))'"
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
- Multi‑user mode
- Provider webhooks/streaming
- Better media support (video, carousels)
- Threads support for timeline

## License

MIT


