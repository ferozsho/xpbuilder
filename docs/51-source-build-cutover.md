# 5.1 (xprompt) source-build cutover runbook

Status as of **2026-08-26**. This runbook is the plan for moving the **5.1
production site (`xprompt-prod`, Moodle 5.1 at `https://xprompt.openxpertz.com`)
onto the XPBuilder source-built Superset 6.1.0 runtime**.

It was NOT executed — it is prepared for review/execution when the site owner
is available, because the 5.1 cutover is gated behind the migration preflight
in [`migration.md`](migration.md) and several prerequisites are missing.

## Verified current state (2026-08-26, VM 76.13.247.208)

| Item | State |
| --- | --- |
| 5.2 (xp521) XPBuilder | **Live and verified** — source-built image `openxpertz-xpbuilder:local` (e930f473…), all services healthy, `https://xp521superset.openxpertz.com` login=200 |
| 5.1 XPBuilder `.env` | **Missing** — `instances/xprompt/.env` does not exist |
| 5.1 registry entry | **Commented out** in `openxpertz-deploy/customers/xprompt-prod.yaml` ("enable only after legacy-volume migration preflight") |
| 5.1 Superset containers | **None running** (`xprompt_superset*` absent) |
| 5.1 legacy volumes | **Absent on this VM** — only `*superset52*` volumes exist; no `local_xpromptsuperset_superset_db_data` etc. |
| 5.1 nginx site | **Missing** — only `xp521superset.openxpertz.com` exists |
| XPBUILDER keys in `/var/www/xprompt/.env` | **None** (Moodle-only env) |

Conclusion: the 5.1 site is **not yet on XPBuilder** and its legacy Superset
data is not present on this VM. Do not attempt `up` until the prerequisites
below are resolved.

## Blocking prerequisites (must be gathered from the site owner)

1. **Legacy secrets** — the values to preserve from the old 5.1 Superset
   stack's `.env` (they may live in git history of the old checkout or an old
   host): `SUPERSET_SECRET_KEY`, `GUEST_TOKEN_JWT_SECRET`, PostgreSQL
   `superset`/`superset_ro` role+password, `SUPERSET_ADMIN_*`, replica root
   password, `MOODLE_REPORTING_USER`/`MOODLE_REPORTING_PASSWORD`, replication
   user/password. A new `SUPERSET_SECRET_KEY` cannot decrypt passwords already
   stored in Superset metadata; a new admin password does not update the
   existing admin account.
2. **Legacy metadata** — where is the 5.1 Superset metadata? The legacy
   volumes are not on this VM. Either (a) provide a custom-format `pg_dump`
   from wherever the old stack last ran, or (b) confirm a fresh metadata start
   is acceptable (dashboards will be recreated by the Moodle connector).
3. **Public domain + nginx** — decide the 5.1 Superset public URL (pattern
   used for 5.2 is `xp521superset.openxpertz.com`; likely
   `xpromptsuperset.openxpertz.com`), then create the nginx site file →
   `localhost:8088` + certbot.
4. **Moodle connector wiring** — the 5.1 Moodle compose (`cmdxboard`) expects
   `SUPERSET_INSTANCE=xprompt`, `SUPERSET_BASE_URL`,
   `SUPERSET_PUBLIC_URL`, `SUPERSET_PROXY_TARGET`; set them to match the
   XPBuilder stack before enabling Advanced BI.

## Execution steps (once prerequisites are met)

```bash
# On the VM, from /var/www/openxpertz-xpbuilder (repo already at the
# source-build commit; image openxpertz-xpbuilder:local already built).
# If building on a fresh host instead: git pull && bin/xpbuilder build (30-60 min).

# 1. Create the site env (adapt xp521 template), preserving the legacy secrets
bin/bootstrap-env.sh \
  --instance xprompt \
  --moodle-network cmdxboard_default \
  --moodle-db xprompt \
  --primary-db-host cmdxboard_mariadb
#   -> instance/xprompt/.env; XPBUILDER_INSTANCE=xprompt, host port 8088
#   -> adopt legacy volumes + XPBUILDER_VOLUMES_EXTERNAL=true, OR fresh start
#   -> replica: unique server-id, reporting account on cmdxboard_mariadb,
#      max_allowed_packet=512M on primary + replica

# 2. Validate only (never init/upgrade against existing metadata)
bin/xpbuilder --env-file /var/www/xprompt/.env config

# 3. Stop any legacy stack WITHOUT -v, then start
bin/xpbuilder --env-file /var/www/xprompt/.env up
bin/xpbuilder --env-file /var/www/xprompt/.env health
python3 tests/contract/runtime_contract.py --base-url http://localhost:8088 ...

# 4. nginx site file for the 5.1 public domain -> localhost:8088 + certbot

# 5. Enable the registry block in openxpertz-deploy/customers/xprompt-prod.yaml
#    (runtime_dir, env_file, auto_start) so start-stacks.sh manages it

# 6. Verify in a real browser (dashboard + embedded), then set auto_start
```

## Rollback

Per [`migration.md`](migration.md): `bin/xpbuilder down` (never `-v`), restore
metadata from the latest `bin/xpbuilder backup` snapshot; there is no legacy
Compose to fall back to (removed from `local_xpromptsuperset`).
