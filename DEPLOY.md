# Deploying DocuSeal Pro

## What this app needs from a host

DocuSeal is a Ruby on Rails application, not a PHP or static site. A host must provide:

| Requirement | Why |
|---|---|
| Ruby 4.0.1 + Rails | The whole application |
| A long-lived process | `config/puma.rb` loads `sidekiq_embed` (background jobs inside the web process) and `redis_server`, which **forks an actual `redis-server` binary** |
| Native libraries | `libvips`, `libpdfium.so`, ONNX Runtime + a field-detection model, fontforge-merged fonts |
| A persistent writable volume | `/data/docuseal` holds attachments, the Redis dump, and the generated env file |
| PostgreSQL | Primary datastore (SQLite works only for trials) |
| Root / Docker | To install the native libraries above |

Practically: **anything that runs a Docker container with a persistent volume.**

## Hosts that will NOT work

**Shared / cPanel-style hosting**, including **Hostinger's Cloud Startup, Cloud
Professional and Cloud Enterprise** plans. Despite the "Cloud" name these are
shared LiteSpeed + PHP hosting: no root, no Docker, and SSH is jailed to your
home directory. Hostinger's own documentation routes Rails customers to VPS
plans — their shared tiers do not support Ruby on Rails at all.

**Vercel / Netlify / Cloudflare Pages.** No Ruby runtime, no persistent disk,
no long-lived processes, and a request body cap well under normal PDF uploads.
Serverless functions also cannot fork the Redis daemon this app starts.

You can still use a shared-hosting plan for the **domain, DNS and email** while
the app itself runs elsewhere — see below.

## Hosts that work

| Option | Notes |
|---|---|
| **Hostinger VPS (KVM 1–8)** | Root + Docker. KVM 2 (2 vCPU / 8 GB) is the comfortable floor; KVM 1 (4 GB) is fine for light use |
| **Railway / Render / Fly.io** | Docker-native, attach a persistent volume, ~$5–10/mo |
| **DigitalOcean / Hetzner / Linode** | Plain VPS, same setup as below |

Point your existing domain at whichever you pick — the domain does not have to
live on the same provider as the app.

## Quick start (any Docker host)

```sh
cp .env.example .env
openssl rand -hex 64          # paste into SECRET_KEY_BASE
openssl rand -hex 24          # paste into POSTGRES_PASSWORD
# set HOST to your domain, then:

docker compose -f docker-compose.prod.yml up -d
```

Caddy fetches a TLS certificate automatically, so point your domain's A record
at the server first. The app is reachable on `https://$HOST` once the health
check passes (first boot takes ~90s while migrations run).

## Sizing

Everything runs in one container: Puma + embedded Sidekiq + embedded Redis +
libvips + the ONNX model. Budget **2 GB RAM minimum, 4 GB comfortable**. Leave
`WEB_CONCURRENCY=0` unless you have RAM to spare — each extra Puma worker
duplicates the Sidekiq threads and their database connections.

Build the image off-box (CI publishes to `ghcr.io/faizkhay/docuseal-pro`) or
expect the webpack build to take a while on a small VPS.

## Using an external database

The app takes a plain `DATABASE_URL`, so Supabase, Neon, or RDS all work. Set
it directly in `docker-compose.prod.yml` and remove the `postgres` service.

Two caveats:

- Use a **session-mode** pooler or the direct connection. Rails relies on
  prepared statements and takes advisory locks during migrations, both of which
  transaction-mode pgBouncer (Supabase port `6543`) breaks.
- Each app process opens `RAILS_MAX_THREADS + SIDEKIQ_THREADS` connections —
  20 by default. Size the plan accordingly.

If the app and database are in different regions the latency will be obvious.
Co-locating Postgres on the same box is usually both faster and cheaper.

## State to back up

- The `docuseal` volume — attachments and the generated env file
- The `pg_data` volume — the database
- Your `SECRET_KEY_BASE` — losing it invalidates sessions, 2FA secrets and
  encrypted columns

`postgres:18` note: the image declares `VOLUME /var/lib/postgresql` and defaults
`PGDATA` to `/var/lib/postgresql/18/docker`. Mounting at
`/var/lib/postgresql/data` (the pre-18 convention) leaves the data directory
inside the container layer, where it is lost on recreate.
