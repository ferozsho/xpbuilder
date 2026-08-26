# OpenXpertz XPBuilder

Standalone Apache Superset runtime for OpenXpertz Advanced BI dashboards.
XPBuilder owns the container image, Superset configuration, branding, workers,
metadata services, and the read-only Moodle reporting replica. Moodle-specific
authentication, capabilities, mappings, and UI integration remain in the thin
`local_xpromptsuperset` connector plugin.

The same XPBuilder release is deployed once per Moodle site. A Moodle 5.1 site
and a Moodle 5.2 site use the same image and Compose definition, but keep
separate instance names, ports, networks, PostgreSQL metadata, Redis data, and
MariaDB replica volumes.

## Safety rules

- Never use `apache/superset:latest`. The base image is pinned by version and
  digest in `Dockerfile`.
- Never place credentials in Compose, customer YAML, command documentation, or
  another env file. Each deployment reads secrets from a file named `.env`.
- Never run first-time initialization against an existing metadata volume.
- Never remove volumes during normal `down` or rollback operations.
- Migrate one site at a time and retain the legacy Compose definition until the
  new instance has passed its soak period.

## Quick start

Create an isolated local configuration:

```bash
bin/bootstrap-env.sh --instance xpbuilder-dev \
  --moodle-network cmdxboard_default \
  --moodle-db xprompt \
  --primary-db-host cmdxboard_mariadb
```

Review `.env`, provision the matching replication account on the Moodle
primary, and then run:

```bash
bin/xpbuilder config
bin/xpbuilder build
bin/xpbuilder init
bin/xpbuilder up
bin/xpbuilder health
```

`init` requires `XPBUILDER_ALLOW_INITIALIZE=yes` in `.env`. Set it back to
`no` immediately after a new stack is initialized. Existing stacks must be
started with `up` and must not be initialized again.

Use a site-specific `.env` outside the checkout with:

```bash
bin/xpbuilder --env-file /path/to/site/.env up
```

Only files whose basename is exactly `.env` are accepted.

## Commands

| Command | Purpose |
| --- | --- |
| `config` | Validate `.env` and render the resolved Compose model |
| `build` | Build the pinned XPBuilder image |
| `init` | Initialize a brand-new metadata database explicitly |
| `upgrade` | Run an explicitly enabled Superset schema upgrade |
| `up` | Start or converge the complete site instance |
| `down` | Stop containers without deleting volumes |
| `ps` | Show the actual Compose services, state, and ports |
| `health` | Verify container health and the Superset health endpoint |
| `backup` | Create a PostgreSQL metadata backup and manifest |
| `restore` | Restore a selected backup with explicit confirmation |

Before the first cutover, use `bin/backup-legacy.sh` against the still-running
plugin-owned Compose project. The normal `backup` command applies only after
XPBuilder owns the metadata service.

Configuration is documented in [docs/configuration.md](docs/configuration.md),
the connector boundary in [docs/connector-contract.md](docs/connector-contract.md),
cutover/rollback in [docs/migration.md](docs/migration.md), and the current
5.1/5.2 local migration map in [docs/local-cutover.md](docs/local-cutover.md).

## Compatibility

The machine-readable contract is [compatibility.json](compatibility.json).
The initial extraction targets:

- Moodle 4.5-5.1 with the `local_xpromptsuperset` 1.x connector.
- Moodle 5.2 with `local_xpromptsuperset` 2.0.8 or newer.
- Apache Superset 6.1.0 at the image digest recorded in `Dockerfile`.

The 2.x connector release and its Moodle 5.2 CI coverage are rollout gates;
XPBuilder must not be promoted to production 5.2 before they are green.

Connector release archives are verified to exclude Docker Compose, Superset
configuration, worker bootstrap, replica bootstrap, and branding-runtime
files. Those assets are built and released only from this repository.

## Development

```bash
tests/static.sh
tests/integration.sh
```

The integration test uses a uniquely named temporary Compose project and
volumes, then removes only those test resources.
