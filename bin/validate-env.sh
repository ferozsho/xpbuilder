#!/usr/bin/env bash

set -euo pipefail

env_file="${1:-}"
if [ -z "$env_file" ] || [ ! -f "$env_file" ]; then
    echo "ERROR: .env file not found: ${env_file:-<not provided>}" >&2
    exit 1
fi

if [ "$(basename "$env_file")" != ".env" ]; then
    echo "ERROR: configuration file must be named exactly .env" >&2
    exit 1
fi

mode="$(stat -c '%a' "$env_file")"
if [ $((10#$mode % 100)) -ne 0 ]; then
    echo "ERROR: $env_file must not be readable or writable by group/other (use chmod 600)" >&2
    exit 1
fi

duplicates="$(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$env_file" | sort | uniq -d)"
if [ -n "$duplicates" ]; then
    echo "ERROR: duplicate keys in $env_file" >&2
    printf '%s\n' "$duplicates" >&2
    exit 1
fi

value_of() {
    local key="$1"
    sed -n "s/^${key}=//p" "$env_file" | tail -1
}

required_keys=(
    XPBUILDER_INSTANCE XPBUILDER_HOST_PORT XPBUILDER_INTERNAL_NETWORK
    XPBUILDER_METADATA_VOLUME XPBUILDER_REDIS_VOLUME XPBUILDER_REPLICA_VOLUME
    XPBUILDER_VOLUMES_EXTERNAL XPBUILDER_ALLOWED_ORIGINS
    MOODLE_NETWORK MOODLE_DB_NAME MOODLE_DB_USER MOODLE_DB_PASSWORD
    PRIMARY_DB_HOST PRIMARY_DB_PORT MARIADB_SERVER_ID MARIADB_ROOT_PASSWORD
    MARIADB_REPLICATION_USER MARIADB_REPLICATION_PASSWORD
    POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB SUPERSET_REDIS_PASSWORD
    SUPERSET_SECRET_KEY GUEST_TOKEN_JWT_SECRET GUEST_TOKEN_JWT_AUDIENCE
    SUPERSET_ADMIN_USERNAME SUPERSET_ADMIN_PASSWORD SUPERSET_ADMIN_FIRSTNAME
    SUPERSET_ADMIN_LASTNAME SUPERSET_ADMIN_EMAIL
)

missing=()
for key in "${required_keys[@]}"; do
    [ -n "$(value_of "$key")" ] || missing+=("$key")
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: missing required .env keys: ${missing[*]}" >&2
    exit 1
fi

instance="$(value_of XPBUILDER_INSTANCE)"
host_port="$(value_of XPBUILDER_HOST_PORT)"
primary_port="$(value_of PRIMARY_DB_PORT)"
server_id="$(value_of MARIADB_SERVER_ID)"
database="$(value_of MOODLE_DB_NAME)"
external="$(value_of XPBUILDER_VOLUMES_EXTERNAL)"
origins="$(value_of XPBUILDER_ALLOWED_ORIGINS)"

[[ "$instance" =~ ^[a-z][a-z0-9_-]*$ ]] || {
    echo "ERROR: XPBUILDER_INSTANCE must match ^[a-z][a-z0-9_-]*$" >&2
    exit 1
}
[[ "$database" =~ ^[A-Za-z0-9_]+$ ]] || {
    echo "ERROR: MOODLE_DB_NAME may contain only letters, numbers, and underscores" >&2
    exit 1
}
for number in "$host_port" "$primary_port" "$server_id"; do
    [[ "$number" =~ ^[0-9]+$ ]] || {
        echo "ERROR: configured ports and server IDs must be numeric" >&2
        exit 1
    }
done
if [ "$host_port" -lt 1 ] || [ "$host_port" -gt 65535 ] \
    || [ "$primary_port" -lt 1 ] || [ "$primary_port" -gt 65535 ]; then
    echo "ERROR: configured port is outside 1-65535" >&2
    exit 1
fi
[[ "$external" = "true" || "$external" = "false" ]] || {
    echo "ERROR: XPBUILDER_VOLUMES_EXTERNAL must be true or false" >&2
    exit 1
}
if [[ "$origins" == *'*'* ]]; then
    echo "ERROR: XPBUILDER_ALLOWED_ORIGINS must list explicit origins; wildcard is forbidden" >&2
    exit 1
fi

secret_keys=(
    MOODLE_DB_PASSWORD MARIADB_ROOT_PASSWORD MARIADB_REPLICATION_PASSWORD
    POSTGRES_PASSWORD SUPERSET_REDIS_PASSWORD SUPERSET_SECRET_KEY
    GUEST_TOKEN_JWT_SECRET SUPERSET_ADMIN_PASSWORD
)
# A greenfield stack generates its own secrets with a 16-character floor. A
# legacy adoption (XPBUILDER_VOLUMES_EXTERNAL=true) keeps the EXISTING
# credentials verbatim so the adopted volumes keep working — those values may
# legitimately be shorter (e.g. postgres 'superset', admin 'admin'), so only
# require them to be present and warn when they are below the normal floor.
if [ "$external" = "true" ]; then
    min_secret_len=1
else
    min_secret_len=16
fi
for key in "${secret_keys[@]}"; do
    value="$(value_of "$key")"
    if [ "${#value}" -lt "$min_secret_len" ]; then
        echo "ERROR: $key must contain at least $min_secret_len characters" >&2
        exit 1
    fi
    if [ "$external" = "true" ] && [ "${#value}" -lt 16 ]; then
        echo "WARNING: $key is shorter than 16 characters (preserved legacy credential)" >&2
    fi
done

if [ "$(value_of SUPERSET_SECRET_KEY)" = "$(value_of GUEST_TOKEN_JWT_SECRET)" ]; then
    echo "ERROR: SUPERSET_SECRET_KEY and GUEST_TOKEN_JWT_SECRET must be different" >&2
    exit 1
fi

echo "XPBuilder .env validation passed for instance: $instance"
