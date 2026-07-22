#!/bin/bash
set -euo pipefail

###
# Provision a new tenant farm on this multisite deployment.
#
# Usage: ./add-tenant.sh <name> ["Site title"]
#
# The tenant is served at https://<name>.$FARM_DOMAIN with its own
# PostgreSQL database, database user, files directory, and admin account.
# Requires a wildcard DNS record (*.$FARM_DOMAIN) pointing at this server.
###

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No .env found — run this script from the deploy directory." >&2
  exit 1
fi
set -a; . ./.env; set +a

NAME="${1:-}"
if ! [[ "$NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "Usage: $0 <name> [\"Site title\"]" >&2
  echo "<name> must be lowercase letters, digits, and hyphens (e.g. greenacres)." >&2
  exit 1
fi
TITLE="${2:-$NAME}"

if [ -z "${FARM_DOMAIN:-}" ] || [[ "$FARM_DOMAIN" == :* ]]; then
  echo "FARM_DOMAIN must be set to a real domain in .env before adding tenants." >&2
  exit 1
fi

DOMAIN="$NAME.$FARM_DOMAIN"
DB_NAME="tenant_${NAME//-/_}"
DB_USER="$DB_NAME"
DB_PASS="$(openssl rand -hex 16)"
ADMIN_PASS="$(openssl rand -base64 12)"
PGUSER="${POSTGRES_USER:-farm}"

if [ -e "sites/$DOMAIN" ]; then
  echo "sites/$DOMAIN already exists — tenant name is taken." >&2
  exit 1
fi

echo "==> Creating database $DB_NAME"
docker compose exec -T db psql -U "$PGUSER" -v ON_ERROR_STOP=1 \
  -c "CREATE ROLE \"$DB_USER\" WITH LOGIN PASSWORD '$DB_PASS';" \
  -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

echo "==> Installing $DOMAIN (this takes a few minutes)"
docker compose exec -T -u www-data www drush site:install farm \
  --sites-subdir="$DOMAIN" \
  --db-url="pgsql://$DB_USER:$DB_PASS@db/$DB_NAME" \
  --site-name="$TITLE" \
  --account-name=admin \
  --account-pass="$ADMIN_PASS" \
  --yes

echo "==> Configuring reverse proxy settings for $DOMAIN"
ESCAPED_DOMAIN="$(printf '%s' "$DOMAIN" | sed 's/\./\\./g')"
cat >> "sites/$DOMAIN/settings.php" <<EOF

\$settings['reverse_proxy'] = TRUE;
\$settings['reverse_proxy_addresses'] = ['172.16.0.0/12'];
\$settings['reverse_proxy_trusted_headers'] =
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_FOR |
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PROTO |
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_HOST |
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PORT;
\$settings['trusted_host_patterns'] = ['^$ESCAPED_DOMAIN\$'];
EOF

echo "==> Enabling HTTPS for $DOMAIN"
cat > "tenants/$DOMAIN.caddy" <<EOF
$DOMAIN {
	reverse_proxy www:80
}
EOF
docker compose exec -T proxy caddy reload --config /etc/caddy/Caddyfile

echo
echo "Tenant created successfully!"
echo "  URL:            https://$DOMAIN"
echo "  Admin username: admin"
echo "  Admin password: $ADMIN_PASS"
echo "  Database:       $DB_NAME (user $DB_USER, password $DB_PASS)"
echo
echo "Save these credentials now — the passwords are not stored anywhere else."
