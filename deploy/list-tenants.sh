#!/bin/bash
set -euo pipefail

###
# List tenant farms hosted on this deployment.
#
# Usage: ./list-tenants.sh
###

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No .env found — run this script from the deploy directory." >&2
  exit 1
fi
set -a; . ./.env; set +a
PGUSER="${POSTGRES_USER:-farm}"

shopt -s nullglob
FOUND=0
printf '%-45s %-22s %-10s %s\n' 'DOMAIN' 'DATABASE' 'DB SIZE' 'FILES'
for f in tenants/*.caddy; do
  DOMAIN="$(basename "$f" .caddy)"
  [ "$DOMAIN" = "_placeholder" ] && continue
  FOUND=1
  NAME="${DOMAIN%%.*}"
  DB_NAME="tenant_${NAME//-/_}"
  DB_SIZE="$(docker compose exec -T db psql -U "$PGUSER" -tA \
    -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null || echo '?')"
  FILES_SIZE="$(du -sh "sites/$DOMAIN" 2>/dev/null | cut -f1 || echo '?')"
  printf '%-45s %-22s %-10s %s\n' "$DOMAIN" "$DB_NAME" "$DB_SIZE" "$FILES_SIZE"
done

if [ "$FOUND" = 0 ]; then
  echo '(no tenants yet — create one with ./add-tenant.sh <name> "Site title")'
fi
