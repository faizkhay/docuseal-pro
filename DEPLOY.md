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

## Required environment for a SaaS deploy

Beyond the basics in `.env.example`, a public SaaS needs these set explicitly:

| Variable | Why it matters |
|---|---|
| `SECRET_KEY_BASE` | Generate once with `openssl rand -hex 64` and never rotate. It also derives the Redis password and the encryption secret for 2FA and encrypted columns. |
| `APP_URL` | Must match the host users actually browse, scheme included. A mismatch breaks checkout redirects and signing links in ways that look like application bugs. |
| `HOST` | Same host, without the scheme. |
| `FORCE_SSL` | `true`. |
| `DATABASE_URL` | Postgres. Session-mode pooler or direct connection only. |
| `SMTP_*` | Without these the app cannot send a single signing invitation. |
| `SIGNUP_ENABLED` | `true` to open self-serve registration. |
| `BILLING_ENABLED` | Leave unset until a real payment provider replaces the mock. |
| `PRODUCT_NAME` | Defaults to SignFlow; set it if you rename again. |

## Railway

Railway builds this repo's `Dockerfile` directly. `railway.json` pins the
builder, the `/up` health check, and — importantly — **one replica**.

### Why `numReplicas` must stay at 1

Each container runs its own embedded Redis and its own Sidekiq. A second
replica would get a *separate* Redis, so jobs enqueued on replica A would never
be seen by replica B, and both would run migrations on boot. To scale past one
container you must first externalise Redis: set `REDIS_URL` to a Railway Redis
service (which makes the app skip starting its own), then split the web and
worker into separate services.

### Setup

1. **New Project → Deploy from GitHub repo**, pick this repository.
2. **Add a Postgres service** (New → Database → PostgreSQL). Railway exposes it
   as `DATABASE_URL` on the Postgres service.
3. **Attach a volume to the app service**, mount path `/data/docuseal`. Without
   this, attachments and the generated env file vanish on every deploy.
4. **Set variables** on the app service:

   | Variable | Value |
   |---|---|
   | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` (Railway reference syntax) |
   | `SECRET_KEY_BASE` | `openssl rand -hex 64` — generate once, never change |
   | `HOST` | your custom domain, e.g. `sign.example.com` |
   | `APP_URL` | `https://sign.example.com` |
   | `FORCE_SSL` | `true` |
   | `WORKDIR` | `/data/docuseal` |
   | `SMTP_*` | see `.env.example` |

   Leave `PORT` alone — Railway injects it and `config/puma.rb` reads it.
5. **Add your custom domain** under Settings → Networking, then point a CNAME
   at the Railway target.

### Cost

Railway bills actual per-second usage, not allocation: roughly **$10 per GB of
RAM** and **$20 per vCPU** per month, plus $0.15/GB for volumes and $0.05/GB
egress. This app idles around 1.2–1.5 GB with low CPU, so expect **≈$20–25/mo**
for app + Postgres + volume, less the $5 Hobby credit.

A comparable VPS is cheaper in raw cost; Railway's premium buys you no server
administration, automatic TLS, and deploy-on-push.

### Build note

The `Dockerfile` downloads fonts and pdfium, compiles native gems, and runs a
full webpack build. First deploy takes a while. If Railway's build times out,
build in GitHub Actions instead (the workflow publishes to
`ghcr.io/faizkhay/docuseal-pro`) and point Railway at that image.
