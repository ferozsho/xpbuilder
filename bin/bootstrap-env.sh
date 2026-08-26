#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$root/.env"
instance=""
host_port="8088"
moodle_network=""
moodle_db=""
primary_db_host=""
primary_db_port="3306"
server_id="2"
allowed_origins=""

usage() {
    echo "Usage: bootstrap-env.sh --instance NAME --moodle-network NAME --moodle-db NAME --primary-db-host NAME [options]" >&2
    echo "Options: --env-file /path/.env --host-port PORT --primary-db-port PORT --server-id ID --allowed-origins CSV" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --env-file) env_file="${2:-}"; shift 2 ;;
        --instance) instance="${2:-}"; shift 2 ;;
        --host-port) host_port="${2:-}"; shift 2 ;;
        --moodle-network) moodle_network="${2:-}"; shift 2 ;;
        --moodle-db) moodle_db="${2:-}"; shift 2 ;;
        --primary-db-host) primary_db_host="${2:-}"; shift 2 ;;
        --primary-db-port) primary_db_port="${2:-}"; shift 2 ;;
        --server-id) server_id="${2:-}"; shift 2 ;;
        --allowed-origins) allowed_origins="${2:-}"; shift 2 ;;
        *) usage ;;
    esac
done

if [ "$(basename "$env_file")" != ".env" ]; then
    echo "ERROR: the configuration file must be named exactly .env" >&2
    exit 1
fi

for value in "$instance" "$moodle_network" "$moodle_db" "$primary_db_host"; do
    [ -n "$value" ] || usage
done

if ! [[ "$instance" =~ ^[a-z][a-z0-9_-]*$ ]] \
    || ! [[ "$moodle_db" =~ ^[A-Za-z0-9_]+$ ]] \
    || ! [[ "$host_port" =~ ^[0-9]+$ ]] \
    || ! [[ "$primary_db_port" =~ ^[0-9]+$ ]] \
    || ! [[ "$server_id" =~ ^[0-9]+$ ]]; then
    echo "ERROR: invalid instance, database, port, or server ID" >&2
    exit 1
fi

if [ -e "$env_file" ]; then
    echo "ERROR: refusing to overwrite existing $env_file" >&2
    exit 1
fi

command -v openssl >/dev/null 2>&1 || {
    echo "ERROR: openssl is required to generate deployment secrets" >&2
    exit 1
}

if [ -z "$allowed_origins" ]; then
    allowed_origins="http://localhost:${host_port},https://localhost:${host_port}"
fi

secret() {
    openssl rand -hex "$1"
}

umask 077
mkdir -p "$(dirname "$env_file")"

postgres_password="$(secret 24)"
redis_password="$(secret 24)"
superset_secret="$(secret 32)"
guest_secret="$(secret 32)"
admin_password="$(secret 18)"
reporting_password="$(secret 24)"
replication_password="$(secret 24)"
replica_root_password="$(secret 24)"

{
    printf 'XPBUILDER_VERSION=0.1.0\n'
    printf 'XPBUILDER_IMAGE=openxpertz-xpbuilder:local\n'
    printf 'XPBUILDER_INSTANCE=%s\n' "$instance"
    printf 'XPBUILDER_HOST_PORT=%s\n' "$host_port"
    printf 'XPBUILDER_MOODLE_ALIAS=superset\n'
    printf 'XPBUILDER_INTERNAL_NETWORK=%s_xpbuilder_internal\n' "$instance"
    printf 'XPBUILDER_METADATA_VOLUME=%s_xpbuilder_metadata\n' "$instance"
    printf 'XPBUILDER_REDIS_VOLUME=%s_xpbuilder_redis\n' "$instance"
    printf 'XPBUILDER_REPLICA_VOLUME=%s_xpbuilder_replica\n' "$instance"
    printf 'XPBUILDER_VOLUMES_EXTERNAL=false\n'
    printf 'XPBUILDER_ALLOWED_ORIGINS=%s\n' "$allowed_origins"
    printf 'XPBUILDER_APP_NAME=Advance BI\n'
    printf 'XPBUILDER_ALLOW_INITIALIZE=yes\n'
    printf 'XPBUILDER_ALLOW_SCHEMA_UPGRADE=no\n'
    printf 'XPBUILDER_ALLOW_RESTORE=no\n'
    printf 'MOODLE_NETWORK=%s\n' "$moodle_network"
    printf 'MOODLE_DB_NAME=%s\n' "$moodle_db"
    printf 'MOODLE_REPORTING_USER=xpbuilder_ro\n'
    printf 'MOODLE_REPORTING_PASSWORD=%s\n' "$reporting_password"
    printf 'PRIMARY_DB_HOST=%s\n' "$primary_db_host"
    printf 'PRIMARY_DB_PORT=%s\n' "$primary_db_port"
    printf 'MARIADB_SERVER_ID=%s\n' "$server_id"
    printf 'MARIADB_ROOT_PASSWORD=%s\n' "$replica_root_password"
    printf 'MARIADB_REPLICATION_USER=xpbuilder_repl\n'
    printf 'MARIADB_REPLICATION_PASSWORD=%s\n' "$replication_password"
    printf 'POSTGRES_USER=xpbuilder\n'
    printf 'POSTGRES_PASSWORD=%s\n' "$postgres_password"
    printf 'POSTGRES_DB=xpbuilder\n'
    printf 'SUPERSET_REDIS_PASSWORD=%s\n' "$redis_password"
    printf 'SUPERSET_SECRET_KEY=%s\n' "$superset_secret"
    printf 'GUEST_TOKEN_JWT_SECRET=%s\n' "$guest_secret"
    printf 'GUEST_TOKEN_JWT_AUDIENCE=http://localhost:%s\n' "$host_port"
    printf 'SUPERSET_ADMIN_USERNAME=superset_admin\n'
    printf 'SUPERSET_ADMIN_PASSWORD=%s\n' "$admin_password"
    printf 'SUPERSET_ADMIN_FIRSTNAME=XPBuilder\n'
    printf 'SUPERSET_ADMIN_LASTNAME=Administrator\n'
    printf 'SUPERSET_ADMIN_EMAIL=xpbuilder-admin@mailinator.com\n'
    printf 'SUPERSET_LOG_LEVEL=INFO\n'
} > "$env_file"

unset postgres_password redis_password superset_secret guest_secret admin_password
unset reporting_password replication_password replica_root_password

chmod 0600 "$env_file"
echo "Created protected deployment configuration: $env_file"
echo "Before starting the replica, provision the matching replication account on the Moodle primary."
