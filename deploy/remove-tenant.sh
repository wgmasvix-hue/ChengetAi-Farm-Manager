#!/bin/bash
set -euo pipefail

###
# Permanently remove a tenant farm and ALL of its data.
#
# Usage: ./remove-tenant.sh <name>
#
# Deletes the tenant's database, database user, site files, and HTTPS
# configuration. This cannot be undone — take a backup first:
#   docker compose exec -T db pg_dump -U farm tenant_<name> > tenant_<name>.sql
#   tar czf tenant_<name>_files.tar.gz sites/<name>.<domain>
###

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No .env found — run this script from the deploy directory." >&2
  exit 1
fi
set -a; . ./.env; set +a

NAME="${1:-}"
if ! [[ "$NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "Usage: $0 <name>" >&2
  exit 1
fi

DOMAIN="$NAME.$FARM_DOMAIN"
DB_NAME="tenant_${NAME//-/_}"
DB_USER="$DB_NAME"
PGUSER="${POSTGRES_USER:-farm}"

if [ ! -e "sites/$DOMAIN" ]; then
  echo "sites/$DOMAIN does not exist — no such tenant." >&2
  exit 1
fi

echo "This PERMANENTLY deletes the tenant at https://$DOMAIN:"
echo "  - database $DB_NAME and user $DB_USER"
echo "  - all uploaded files and settings in sites/$DOMAIN"
echo
printf 'Type the full tenant domain (%s) to confirm: ' "$DOMAIN"
read -r CONFIRM
if [ "$CONFIRM" != "$DOMAIN" ]; then
  echo "Confirmation did not match — nothing was deleted." >&2
  exit 1
fi

echo "==> Dropping database $DB_NAME"
docker compose exec -T db psql -U "$PGUSER" -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS \"$DB_NAME\";" \
  -c "DROP ROLE IF EXISTS \"$DB_USER\";"

echo "==> Removing HTTPS configuration"
rm -f "tenants/$DOMAIN.caddy"
docker compose exec -T proxy caddy reload --config /etc/caddy/Caddyfile

echo "==> Removing site files"
rm -rf "sites/$DOMAIN"

echo
echo "Tenant $DOMAIN removed."
