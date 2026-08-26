#!/usr/bin/env bash

set -euo pipefail

required() {
    local name="$1"
    if [ -z "${!name:-}" ]; then
        echo "ERROR: $name must be provided through .env" >&2
        exit 1
    fi
}

valid_identifier() {
    [[ "$1" =~ ^[A-Za-z0-9_]+$ ]]
}

sql_string() {
    printf '%s' "$1" | sed "s/'/''/g"
}

for name in PRIMARY_DB_HOST PRIMARY_DB_PORT MARIADB_REPLICATION_USER \
    MARIADB_REPLICATION_PASSWORD MARIADB_ROOT_PASSWORD MARIADB_DATABASE; do
    required "$name"
done

if ! [[ "$PRIMARY_DB_HOST" =~ ^[A-Za-z0-9_.-]+$ ]] \
    || ! [[ "$PRIMARY_DB_PORT" =~ ^[0-9]+$ ]] \
    || ! valid_identifier "$MARIADB_REPLICATION_USER" \
    || ! valid_identifier "$MARIADB_DATABASE"; then
    echo "ERROR: invalid primary host, port, replication user, or database name" >&2
    exit 1
fi

dump_file="/tmp/${MARIADB_DATABASE}_initial.sql"
trap 'rm -f "$dump_file"' EXIT

echo "Waiting for the Moodle primary database"
for attempt in $(seq 1 60); do
    if mariadb \
        -h "$PRIMARY_DB_HOST" \
        -P "$PRIMARY_DB_PORT" \
        -u "$MARIADB_REPLICATION_USER" \
        -p"$MARIADB_REPLICATION_PASSWORD" \
        -e "SELECT 1" >/dev/null 2>&1; then
        break
    fi
    if [ "$attempt" -eq 60 ]; then
        echo "ERROR: primary database was not reachable after 120 seconds" >&2
        exit 1
    fi
    sleep 2
done

echo "Taking a consistent bootstrap snapshot of the Moodle database"
mariadb-dump \
    -h "$PRIMARY_DB_HOST" \
    -P "$PRIMARY_DB_PORT" \
    -u "$MARIADB_REPLICATION_USER" \
    -p"$MARIADB_REPLICATION_PASSWORD" \
    --single-transaction \
    --master-data=2 \
    --databases "$MARIADB_DATABASE" > "$dump_file"

master_line="$(grep -m1 'CHANGE MASTER TO' "$dump_file" || true)"
master_file="$(printf '%s' "$master_line" | sed -n "s/.*MASTER_LOG_FILE='\([^']*\)'.*/\1/p")"
master_position="$(printf '%s' "$master_line" | sed -n 's/.*MASTER_LOG_POS=\([0-9]*\).*/\1/p')"

if [ -z "$master_file" ] || ! [[ "$master_position" =~ ^[0-9]+$ ]]; then
    echo "ERROR: snapshot did not contain a valid primary binlog position" >&2
    exit 1
fi

echo "Importing the bootstrap snapshot"
mariadb --protocol=socket -u root -p"$MARIADB_ROOT_PASSWORD" < "$dump_file"

primary_host_sql="$(sql_string "$PRIMARY_DB_HOST")"
replication_user_sql="$(sql_string "$MARIADB_REPLICATION_USER")"
replication_password_sql="$(sql_string "$MARIADB_REPLICATION_PASSWORD")"
master_file_sql="$(sql_string "$master_file")"

mariadb --protocol=socket -u root -p"$MARIADB_ROOT_PASSWORD" <<SQL
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='${primary_host_sql}',
  MASTER_PORT=${PRIMARY_DB_PORT},
  MASTER_USER='${replication_user_sql}',
  MASTER_PASSWORD='${replication_password_sql}',
  MASTER_LOG_FILE='${master_file_sql}',
  MASTER_LOG_POS=${master_position};
START SLAVE;
SQL

unset primary_host_sql replication_user_sql replication_password_sql master_file_sql

echo "Waiting for both replication threads"
for attempt in $(seq 1 30); do
    status="$(mariadb --protocol=socket -u root -p"$MARIADB_ROOT_PASSWORD" -e 'SHOW SLAVE STATUS\G')"
    if grep -q 'Slave_IO_Running: Yes' <<<"$status" \
        && grep -q 'Slave_SQL_Running: Yes' <<<"$status"; then
        echo "Moodle read replica is healthy"
        exit 0
    fi
    sleep 2
done

echo "ERROR: replication threads did not become healthy" >&2
exit 1
