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

for name in MARIADB_ROOT_PASSWORD MARIADB_DATABASE MOODLE_REPORTING_USER MOODLE_REPORTING_PASSWORD; do
    required "$name"
done

if ! valid_identifier "$MARIADB_DATABASE" || ! valid_identifier "$MOODLE_REPORTING_USER"; then
    echo "ERROR: database and reporting user names may contain only letters, numbers, and underscores" >&2
    exit 1
fi

reporting_password="$(sql_string "$MOODLE_REPORTING_PASSWORD")"

mariadb --protocol=socket -u root -p"$MARIADB_ROOT_PASSWORD" <<SQL
CREATE USER IF NOT EXISTS '${MOODLE_REPORTING_USER}'@'%' IDENTIFIED BY '${reporting_password}';
ALTER USER '${MOODLE_REPORTING_USER}'@'%' IDENTIFIED BY '${reporting_password}';
GRANT SELECT, SHOW VIEW ON \`${MARIADB_DATABASE}\`.* TO '${MOODLE_REPORTING_USER}'@'%';
GRANT SHOW DATABASES ON *.* TO '${MOODLE_REPORTING_USER}'@'%';
FLUSH PRIVILEGES;
SQL

unset reporting_password
echo "Read-only Moodle reporting user configured"
