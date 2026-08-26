# Migration and rollback

The first migration changes ownership of the runtime files, not Superset
behavior or Moodle mapping data. Use the pinned image and migrate one site at a
time.

## Preflight

1. Run `docker compose ps` against the legacy Superset and Moodle projects.
2. Record the legacy image ID, services, ports, networks, volume names, and
   container aliases.
3. Record counts and IDs for dashboards, charts, datasets, embedded records,
   and Moodle mapping tables.
4. Verify both replica threads and prove the reporting account cannot write.
5. Create a custom-format metadata backup from the running legacy project if
   one is still running. The plugin-owned Compose definition was removed from
   `local_xpromptsuperset`, so either supply a compose file from git history or
   dump directly: `docker exec <legacy-db> pg_dump -U superset -d superset --format=custom`.

   ```bash
   bin/backup-legacy.sh \
     --compose-file /path/to/docker-compose.superset.yml \
     --project LEGACY_PROJECT \
     --destination /absolute/path/to/backups
   ```

   If no legacy project is running, XPBuilder adopts the existing metadata
   volume directly (`XPBUILDER_VOLUMES_EXTERNAL=true`); the volume is read in
   place and never modified.
6. Configure XPBuilder with the exact legacy volume names and
   `XPBUILDER_VOLUMES_EXTERNAL=true`.
7. Run `bin/xpbuilder config`; do not run `init` or `upgrade`.

## Cutover

1. Put Advanced BI in native fallback/maintenance while keeping Moodle online.
2. Take a final `bin/backup-legacy.sh` metadata backup.
3. Stop the legacy Superset project without `--volumes` or `-v`.
4. Start XPBuilder with `bin/xpbuilder --env-file /site/.env up`.
5. Run `ps`, `health`, API contract, replica, Moodle mapping, and real browser
   checks.
6. Create a second backup with `bin/xpbuilder backup` now that XPBuilder owns
   the metadata service.
7. Re-enable Advanced BI only after all checks pass.
8. Keep the XPBuilder backup and any pre-cutover metadata dump for at least
   one release cycle. The plugin-owned legacy Compose/runtime was removed;
   XPBuilder is the only Superset runtime.

First cutover must preserve container DNS aliases and must not run an automatic
Superset metadata migration.

## Rollback

If authentication, mapping counts, guest-token embedding, SSO, replication, or
browser checks fail:

1. Disable Advanced BI and retain native fallback.
2. Run `bin/xpbuilder down`; this never deletes volumes.
3. Restore metadata from the latest `bin/xpbuilder backup` snapshot if needed
   (there is no legacy Compose to restart — the plugin-owned runtime was
   removed).
4. Restore PostgreSQL only if a schema or metadata mutation occurred.
5. Re-run API, mapping, replica, and browser checks before re-enabling the
   feature.

`bin/xpbuilder restore <dump> restore-<instance>` additionally requires
`XPBUILDER_ALLOW_RESTORE=yes` in `.env`.
