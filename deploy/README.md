# Deploying ChengetAi Farm Manager to farm.chengetailabs.co.zw

This directory contains everything needed to run ChengetAi Farm Manager in
production at **https://farm.chengetailabs.co.zw** using Docker Compose:

- `docker-compose.yml` — PostgreSQL database, the ChengetAi Farm Manager web
  application (built from this repository so it includes the ChengetAi
  branding), and a Caddy reverse proxy that automatically obtains and renews
  Let's Encrypt HTTPS certificates.
- `Caddyfile` — reverse proxy configuration for the domain.
- `.env.example` — template for required environment variables.

## Prerequisites

1. **A server** (VPS or dedicated) with ports **80** and **443** open to the
   internet. 2 GB RAM and 20 GB disk is a comfortable minimum.
2. **DNS**: in your DNS provider for `chengetailabs.co.zw`, create an **A
   record** for `farm` pointing to the server's public IP address:

       farm.chengetailabs.co.zw.  A  <your server IP>

   Let's Encrypt certificate issuance will fail until this record resolves to
   the server, so set it up first.
3. **Docker** with the Compose plugin installed on the server:
   https://docs.docker.com/engine/install/

## First deployment

On the server:

```sh
# 1. Clone this repository.
git clone https://github.com/wgmasvix-hue/ChengetAi-Farm-Manager.git
cd ChengetAi-Farm-Manager/deploy

# 2. Configure environment variables.
cp .env.example .env
# Edit .env and set a strong POSTGRES_PASSWORD (openssl rand -base64 24).

# 3. Create the sites directory owned by www-data (UID/GID 33 in the container).
mkdir -p sites keys && sudo chown 33:33 sites keys

# 4. Build and start the stack (the first build takes several minutes).
docker compose up -d --build
```

Then visit **https://farm.chengetailabs.co.zw** and follow the installer:

- Database type: **PostgreSQL**
- Database name: `farm`
- Database username: `farm`
- Database password: the `POSTGRES_PASSWORD` you set in `.env`
- Under *Advanced options*, set Host to: `db`

Complete the installer, create your admin account, and the ChengetAi Farm
Manager setup wizard will guide you through the rest.

## After installation: trusted hosts and reverse proxy settings

Because the application runs behind the Caddy proxy, tell Drupal to trust the
proxy and the domain. Append the following to `deploy/sites/default/settings.php`
(as root or with `sudo`, since the file is owned by `www-data`):

```php
// Only respond to requests for the production hostname.
$settings['trusted_host_patterns'] = [
  '^farm\.chengetailabs\.co\.zw$',
];

// Trust X-Forwarded-* headers from the Caddy reverse proxy so that
// generated URLs use https:// and the real client IP is logged.
$settings['reverse_proxy'] = TRUE;
$settings['reverse_proxy_addresses'] = [$_SERVER['REMOTE_ADDR']];
$settings['reverse_proxy_trusted_headers'] =
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_FOR |
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_HOST |
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PORT |
  \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PROTO;
```

The `settings.php` file may be read-only; make it writable first if needed:

```sh
sudo chmod u+w sites/default/settings.php
# ... edit ...
sudo chmod u-w sites/default/settings.php
```

## Updating

To deploy a new version (e.g. after merging changes to the `4.x` branch):

```sh
cd ChengetAi-Farm-Manager/deploy
git pull
docker compose down
docker compose build --no-cache www
docker compose up -d
```

Then run any pending database updates by visiting
`https://farm.chengetailabs.co.zw/update.php`, or with Drush:

```sh
docker compose exec -u www-data www drush updb
```

All site data lives in `deploy/sites` (settings and uploaded files),
`deploy/db` (PostgreSQL data), and `deploy/keys` (OAuth keys) — these persist
across container rebuilds. **Back them up regularly.**

## Backups

A minimal backup is a database dump plus the `sites` and `keys` directories:

```sh
docker compose exec db pg_dump -U farm farm | gzip > backup-$(date +%F).sql.gz
tar czf sites-backup-$(date +%F).tar.gz sites keys
```

Store backups off the server.
