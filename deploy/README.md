# Deploying ChengetAi Farm Manager with Docker Compose

This directory contains a production Docker Compose stack for ChengetAi Farm
Manager (based on farmOS). It provisions:

- `www` — the ChengetAi Farm Manager web server, built from this repository
  using the Dockerfile in [`../docker`](../docker).
- `db` — a PostgreSQL 17 database with data persisted in `./db`.
- `proxy` — a Caddy reverse proxy that serves the site. With `FARM_DOMAIN`
  set it terminates HTTPS with an automatic Let's Encrypt certificate;
  otherwise it serves plain HTTP on port 80.

## Quick start

On a server with [Docker](https://docs.docker.com/engine/install/) (including
the Compose plugin) installed:

```sh
git clone https://github.com/wgmasvix-hue/ChengetAi-Farm-Manager.git
cd ChengetAi-Farm-Manager/deploy
cp .env.example .env   # set a strong POSTGRES_PASSWORD
mkdir -p sites keys && sudo chown 33:33 sites keys
docker compose up -d --build
```

The first build compiles PHP extensions and runs Composer, so it can take
several minutes. Follow progress with:

```sh
docker compose logs -f
```

Once the containers are up, visit `http://<server-ip>/` (or the port you set
as `WWW_PORT`) and complete the installer. On the database configuration step
choose **PostgreSQL** and enter:

- Database name: `farm` (or your `POSTGRES_DB`)
- Username: `farm` (or your `POSTGRES_USER`)
- Password: your `POSTGRES_PASSWORD`
- Under *Advanced options*, set Host to `db`

## Configuration

All settings live in `.env` (see [`.env.example`](.env.example)):

| Variable | Default | Description |
| --- | --- | --- |
| `POSTGRES_USER` | `farm` | Database user |
| `POSTGRES_PASSWORD` | *(required)* | Database password — must be set |
| `POSTGRES_DB` | `farm` | Database name |
| `FARM_DOMAIN` | *(unset)* | Public domain; enables automatic HTTPS when set |
| `FARMOS_REPO` | this repository | Git repository the codebase is built from |
| `FARMOS_VERSION` | `4.x` | Branch or tag to build |

## Persistence

- `./sites` — Drupal site settings and user-uploaded files
- `./keys` — OAuth2 keys used for API authentication
- `./db` — PostgreSQL data
- `./caddy_data` — TLS certificates issued for `FARM_DOMAIN`

These directories are bind-mounted from the host and survive container
rebuilds. `sites` and `keys` must be owned by user/group ID `33` (`www-data`
inside the container), which is what the `chown 33:33` step above does. Back
up all three directories regularly.

## Multi-tenant hosting

The stack supports hosting multiple independent farms (tenants) from one
server using Drupal's built-in multisite feature. Each tenant gets its own
subdomain, database, database user, files, and admin account — tenants
cannot see each other's data.

One-time setup:

1. Set `FARM_DOMAIN` in `.env` (see above) — tenants live under it, e.g.
   `greenacres.farm.example.com`.
2. At your DNS provider, add a **wildcard A record** `*.farm.example.com`
   pointing at this server's IP, so new tenants need no DNS changes.

Create a tenant:

```sh
./add-tenant.sh greenacres "Green Acres Farm"
```

This provisions the database, installs the site, configures HTTPS for the
subdomain, and prints the tenant's URL and admin credentials. Save them —
they are not stored anywhere else.

List tenants with their database and disk usage:

```sh
./list-tenants.sh
```

Remove a tenant (irreversible — the script asks for confirmation):

```sh
./remove-tenant.sh greenacres
```

Per-tenant backups: dump the tenant's database and copy its site
directory, e.g.

```sh
docker compose exec -T db pg_dump -U farm tenant_greenacres > tenant_greenacres.sql
tar czf tenant_greenacres_files.tar.gz sites/greenacres.farm.example.com
```

All tenants share one codebase, so [updating](#updating) the image updates
every tenant at once; run the database updates step for each site with
`drush updb --uri=https://<tenant-domain>`.

## Updating

Pull the latest code and rebuild:

```sh
cd ChengetAi-Farm-Manager
git pull
cd deploy
docker compose down
docker compose up -d --build
```

Then run database updates:

```sh
docker compose exec -u www-data www drush updb
```

## Custom domain and HTTPS

1. At your DNS provider, create an **A record** pointing the domain (e.g.
   `farm.example.com`) at this server's public IP address, and wait for it
   to resolve.
2. Set `FARM_DOMAIN=farm.example.com` in `.env`.
3. Apply the change:

   ```sh
   docker compose up -d
   ```

Caddy requests a Let's Encrypt certificate on first start (ports 80 and 443
must be reachable from the internet) and renews it automatically. HTTP
requests are redirected to HTTPS.

Because the site now runs behind a reverse proxy, add the following to
`sites/default/settings.php` (adjust the host pattern to your domain) so
that Drupal trusts the proxy's forwarded headers and generates correct
HTTPS URLs:

```php
$settings['reverse_proxy'] = TRUE;
$settings['reverse_proxy_addresses'] = ['172.16.0.0/12'];
$settings['reverse_proxy_trusted_headers'] =
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_FOR |
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PROTO |
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_HOST |
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PORT;
$settings['trusted_host_patterns'] = ['^farm\.example\.com$'];
```
