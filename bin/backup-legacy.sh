#!/usr/bin/env bash

set -euo pipefail

compose_file=""
project=""
destination=""

usage() {
    echo "Usage: backup-legacy.sh --compose-file FILE --project NAME --destination DIR" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --compose-file) compose_file="${2:-}"; shift 2 ;;
        --project) project="${2:-}"; shift 2 ;;
        --destination) destination="${2:-}"; shift 2 ;;
        *) usage ;;
    esac
done

[ -f "$compose_file" ] || {
    echo "ERROR: legacy Compose file not found: ${compose_file:-<not provided>}" >&2
    exit 1
}
[[ "$project" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || {
    echo "ERROR: invalid legacy Compose project name" >&2
    exit 1
}
[ -n "$destination" ] || usage

compose=(docker compose -p "$project" -f "$compose_file")

# Compose is the authority for the actual service/container relationship.
"${compose[@]}" ps -a
container_id="$("${compose[@]}" ps -q superset-db)"
[ -n "$container_id" ] || {
    echo "ERROR: the legacy superset-db service is not created for project $project" >&2
    exit 1
}
state="$(docker inspect --format '{{.State.Status}}' "$container_id")"
[ "$state" = "running" ] || {
    echo "ERROR: the legacy superset-db service must be running (state=$state)" >&2
    exit 1
}

timestamp="$(date -u +%Y%m%d-%H%M%S)"
backup_dir="$destination/$project/$timestamp"
backup="$backup_dir/superset-metadata.dump"
partial="$backup.partial"

umask 077
mkdir -p "$backup_dir"
trap 'rm -f "$partial"' EXIT

echo "Creating read-only legacy metadata backup for $project"
# shellcheck disable=SC2016 # intentionally single-quoted: vars expand inside the container, not on the host
"${compose[@]}" exec -T superset-db sh -ec \
    'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom' > "$partial"

[ -s "$partial" ] || {
    echo "ERROR: legacy PostgreSQL backup is empty" >&2
    exit 1
}
mv "$partial" "$backup"

checksum="$(sha256sum "$backup" | awk '{print $1}')"
image_id="$(docker inspect --format '{{.Image}}' "$container_id")"
python3 - "$backup_dir/manifest.json" "$project" "$timestamp" "$checksum" "$image_id" "$compose_file" <<'PY'
import json
import sys

manifest = {
    'schema_version': 1,
    'source': 'legacy-plugin-compose',
    'instance': sys.argv[2],
    'created_at_utc': sys.argv[3],
    'metadata_backup': 'superset-metadata.dump',
    'sha256': sys.argv[4],
    'superset_db_image_id': sys.argv[5],
    'compose_file': sys.argv[6],
}
with open(sys.argv[1], 'w', encoding='utf-8') as handle:
    json.dump(manifest, handle, indent=2)
    handle.write('\n')
PY

chmod 0600 "$backup" "$backup_dir/manifest.json"
echo "Legacy metadata backup completed: $backup_dir"
