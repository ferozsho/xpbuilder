# Deploy XPBuilder to a new server

XPBuilder is a standalone, stateless Superset runtime. The image
(`openxpertz-xpbuilder:local`) is env-driven: the baked
`config/superset_config.py` reads every site-specific value from the per-site
`.env`, so the **same image runs on any server**. Only three things are
machine-specific and must be provisioned per site:

1. The per-site `.env` (project name, ports, network, origins, secrets).
2. The site's Moodle Docker network (the `up` command refuses to start if
   `MOODLE_NETWORK` does not exist).
3. The data volumes — postgres metadata (dashboards/charts/datasets), Redis,
   and the MariaDB replica — which live in volumes, **not** in the image.

## What travels with the image

| Item | Where it lives | Notes |
| --- | --- | --- |
| Superset runtime + branding | In the image (baked) | Built from `Dockerfile`, pinned base `apache/superset:6.1.0@sha256:fb3464…` |
| Superset config | In the image (baked) | `config/superset_config.py` reads env vars only |
| Per-site settings | `.env` on the server | `XPBUILDER_INSTANCE`, host port, `MOODLE_NETWORK`, origins, secrets, reporting DB user/password |
| Metadata (dashboards, charts, datasets) | External postgres volume | Adopt, restore from backup, or start fresh |
| Redis / replica data | External volumes | Adopt or recreate; replica auto-repositions from binlog |
| Builder CLI + compose | Repo on the server | `bin/xpbuilder`, `compose.yml`, `docker/` |

## Option A — pull a prebuilt image from a registry

1. On the source server, tag and push the image:
   ```bash
   docker tag openxpertz-xpbuilder:local ghcr.io/<org>/openxpertz-xpbuilder:6.1.0-xp1
   docker push ghcr.io/<org>/openxpertz-xpbuilder:6.1.0-xp1
   ```
2. On the target server, pull it and retag to the name the compose file uses:
   ```bash
   docker pull ghcr.io/<org>/openxpertz-xpbuilder:6.1.0-xp1
   docker tag ghcr.io/<org>/openxpertz-xpbuilder:6.1.0-xp1 openxpertz-xpbuilder:local
   ```
3. Clone the builder repo so `bin/xpbuilder` and `compose.yml` are available:
   ```bash
   git clone git@github.com:ferozsho/xpbuilder.git /var/www/openxpertz-xpbuilder
   ```

## Option B — offline transfer (air-gapped)

```bash
docker save openxpertz-xpbuilder:local -o xpbuilder-image.tar
# copy the tarball to the target server, then:
docker load -i xpbuilder-image.tar
git clone git@github.com:ferozsho/xpbuilder.git /var/www/openxpertz-xpbuilder
```

## Option C — build from the repo (recommended for parity)

Because the Dockerfile pins the base image by digest, building anywhere
produces an equivalent image. This is the flow used for the production VM.

```bash
cd /var/www/openxpertz-xpbuilder
git pull            # keep the builder + compose current
bin/xpbuilder --env-file /path/to/site/.env build
```

## Provision the per-site `.env`

Copy the shape of `instances/xp521/.env` (chmod 600) and set:

- `XPBUILDER_INSTANCE` — unique project name (e.g. `xprompt52`).
- Host port for Superset (internal is always 8088) and `MOODLE_NETWORK` —
  must match an existing network on the target server.
- `SUPERSET_SECRET_KEY` / `GUEST_TOKEN_JWT_SECRET` — preserve the site's
  existing values; a new key cannot decrypt passwords already stored in the
  Superset metadata, and `.env` does not change an existing admin password.
- PostgreSQL role/password, Superset admin user/password, replica root
  password, `MOODLE_REPORTING_USER` / `MOODLE_REPORTING_PASSWORD` (the
  reporting user must exist in the site's MariaDB).
- CORS origins for the site URLs (Moodle public URL + Superset public URL).
- `XPBUILDER_VOLUMES_EXTERNAL=true` when adopting existing volumes.

## Provision the data

Pick one:

- **Adopt existing volumes** — set the exact external volume names in `.env`
  (like the legacy cutover). No migration.
- **Restore from backup** — `bin/xpbuilder --env-file <env> backup` on the
  source, copy the snapshot, then `bin/xpbuilder --env-file <env> restore
  <backup>` on the target.
- **Start fresh** — run `bin/xpbuilder --env-file <env> init`, then reconnect
  the Moodle connector so it recreates dashboards.

## Bring it up

```bash
cd /var/www/openxpertz-xpbuilder
bin/xpbuilder --env-file /path/to/site/.env config   # validate
bin/xpbuilder --env-file /path/to/site/.env up       # requires MOODLE_NETWORK
bin/xpbuilder --env-file /path/to/site/.env health
python3 tests/contract/runtime_contract.py --base-url http://localhost:<port> \
    --username <admin> --password <password>
```

## Notes

- The image is stateless; all data lives in volumes. Never remove volumes with
  `down -v` unless you intend to wipe the site.
- The MariaDB replica adopts the primary's binlog position automatically;
  raise `max_allowed_packet` to 512M on **both** the primary and the replica
  to avoid fatal error 1236 on large ROW events (see `compose.yml` and the
  primary's `mariadb-conf/performance.cnf`).
- `bin/xpbuilder` is a bash wrapper around `docker compose` — it works
  identically on any Linux host with Docker; no other runtime is required.
