# Deploying ChengetAi Farm Manager with Docker Compose

This directory contains a production Docker Compose stack for ChengetAi Farm
Manager (based on farmOS). It provisions:

- `www` — the ChengetAi Farm Manager web server, built from this repository
  using the Dockerfile in [`../docker`](../docker).
- `db` — a PostgreSQL 17 database with data persisted in `./db`.

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
| `WWW_PORT` | `80` | Host port the site is served on |
| `FARMOS_REPO` | this repository | Git repository the codebase is built from |
| `FARMOS_VERSION` | `4.x` | Branch or tag to build |

## Persistence

- `./sites` — Drupal site settings and user-uploaded files
- `./keys` — OAuth2 keys used for API authentication
- `./db` — PostgreSQL data

These directories are bind-mounted from the host and survive container
rebuilds. `sites` and `keys` must be owned by user/group ID `33` (`www-data`
inside the container), which is what the `chown 33:33` step above does. Back
up all three directories regularly.

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

## HTTPS

The stack serves plain HTTP. For production use, put a reverse proxy with TLS
termination (e.g. Caddy, Traefik, or Nginx with certbot) in front of the `www`
service, and set `WWW_PORT` to an internal port such as `8080`.
