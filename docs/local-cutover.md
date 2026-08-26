# Local Moodle 5.1 and 5.2 cutover map

This map records the current extraction targets. Re-run `docker compose ps`
and `docker volume inspect` before every cutover because runtime state can
change after this document is written.

| Site | XPBuilder `.env` | Moodle network | Legacy metadata volume | Legacy Redis volume | Legacy replica volume |
| --- | --- | --- | --- | --- | --- |
| Moodle 5.1 | `instances/moodle-5.1/.env` | `cmdxboard_default` | `local_xpromptsuperset_superset_db_data` | `local_xpromptsuperset_superset_redis_data` | `local_xpromptsuperset_superset_replica_data` |
| Moodle 5.2 | `instances/moodle-5.2/.env` | `cmdxboard52_default` | `local_xpromptsuperset_superset52_db_data` | `local_xpromptsuperset_superset52_redis_data` | `local_xpromptsuperset_superset52_replica_data` |

For each site, create its `.env` with the site-specific selectors, then set
the three exact legacy volume names and
`XPBUILDER_VOLUMES_EXTERNAL=true`. Preserve the existing
`SUPERSET_SECRET_KEY`, `GUEST_TOKEN_JWT_SECRET`, PostgreSQL role/password,
Superset administrator username/password, replica root password, reporting
user/password, and replication user/password. A newly generated Superset key
cannot decrypt database passwords stored in existing Superset metadata, and a
new admin password in `.env` does not update an existing Superset account.

Before starting XPBuilder:

1. Confirm the Moodle network and all three volumes exist.
2. Run the legacy project `docker compose ps` and record its image and aliases.
3. Run `bin/backup-legacy.sh` while the legacy metadata service is running.
4. Run XPBuilder `config`; do not run `init` or `upgrade`.
5. Stop the legacy project without `--volumes`.
6. Run XPBuilder `up`, `ps`, `health`, and the runtime contract test.
7. Verify a real Moodle dashboard conversion and embedded dashboard in the
   browser before enabling `auto_start` in the customer registry.

If the `.env` path is absent, `openxpertz-deploy/bin/start-stacks.sh` uses the
retained plugin-owned Compose definition. That fallback is temporary and
exists only to keep rollback possible during the first release cycle.
