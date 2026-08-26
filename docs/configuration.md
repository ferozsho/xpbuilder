# Configuration

Every deployment uses one file named exactly `.env`. It is never committed and
must be mode `0600` or stricter. `bin/validate-env.sh` rejects duplicate,
missing, weak, or wildcard configuration before Docker Compose runs.

## Instance and routing

| Variable | Purpose |
| --- | --- |
| `XPBUILDER_INSTANCE` | Unique Compose project and container prefix |
| `XPBUILDER_HOST_PORT` | Browser-facing host port mapped to Superset 8088 |
| `XPBUILDER_MOODLE_ALIAS` | Compatibility DNS alias on the Moodle network |
| `XPBUILDER_INTERNAL_NETWORK` | Private network for web, worker, DB, and Redis |
| `MOODLE_NETWORK` | Existing external Docker network owned by Moodle |
| `GUEST_TOKEN_JWT_AUDIENCE` | Public URL expected by embedded guest tokens |
| `XPBUILDER_ALLOWED_ORIGINS` | Comma-separated explicit Moodle origins |

Each site must have unique instance, host port, network, MariaDB server ID, and
volume names. Two sites may use the same XPBuilder image version but must not
share mutable volumes.

## Persistent storage

| Variable | Purpose |
| --- | --- |
| `XPBUILDER_METADATA_VOLUME` | Superset PostgreSQL metadata |
| `XPBUILDER_REDIS_VOLUME` | Redis cache and Celery broker persistence |
| `XPBUILDER_REPLICA_VOLUME` | Read-only Moodle MariaDB replica |
| `XPBUILDER_VOLUMES_EXTERNAL` | `true` only when adopting pre-existing volumes |

Legacy cutovers must set the exact current volume names and set
`XPBUILDER_VOLUMES_EXTERNAL=true`. Do not rename or copy volumes during the
first extraction cutover.

## Secrets

The following values are secrets and must exist only in `.env`:

- `SUPERSET_SECRET_KEY`
- `GUEST_TOKEN_JWT_SECRET`
- `SUPERSET_REDIS_PASSWORD`
- `POSTGRES_PASSWORD`
- `MOODLE_DB_PASSWORD`
- `MARIADB_ROOT_PASSWORD`
- `MARIADB_REPLICATION_PASSWORD`
- `SUPERSET_ADMIN_PASSWORD`

The matching usernames, database names, primary host/port, administrator
identity, and replica server ID are also declared in `.env`. The reporting and
replication accounts must be provisioned on the Moodle primary before the
replica's first start.

## Mutation gates

| Variable | Required value | Action enabled |
| --- | --- | --- |
| `XPBUILDER_ALLOW_INITIALIZE` | `yes` | First-time metadata initialization |
| `XPBUILDER_ALLOW_SCHEMA_UPGRADE` | `yes` | Superset metadata schema upgrade |
| `XPBUILDER_ALLOW_RESTORE` | `yes` | Destructive metadata restore |

Keep all three set to `no` during normal operation.
