# wordpress.wpnuxt.com

The headless WordPress backend behind the [WPNuxt](https://github.com/wpnuxt/wpnuxt) demo
([demo.wpnuxt.com](https://demo.wpnuxt.com)), also the public GraphQL endpoint used by the WPNuxt
docs, playgrounds and test fixtures.

It doubles as an **example of how to self-host a WordPress backend for WPNuxt**: WordPress and MySQL
in Docker Compose, behind a reverse proxy, deployed with [Coolify](https://coolify.io). Nothing here
is Coolify-specific except the `SERVICE_FQDN_*` variable; any Docker host with a TLS-terminating
proxy works.

```
docker-compose.yaml         WordPress (custom image) + MySQL 8
docker-compose.local.yaml   local extras: port 8080, http://localhost:8080 as site URL
Dockerfile                  wordpress:php8.5-apache + config below
docker/wp-config-extra.php  WP_HOME/WP_SITEURL from WORDPRESS_URL, https behind the proxy, hardening
docker/php.ini              memory/upload limits
docker/remoteip.conf        real visitor IPs behind the reverse proxy
docker/mu-plugins/          installed into the volume on every start (docker/entrypoint.sh)
scripts/pull-production.sh  copies wp-content + database of an existing site into ./data/
scripts/import.sh           loads ./data/ into a running stack (local or on the server)
```

## How it runs

Apart from `docker/mu-plugins/`, there is no custom code: WordPress core, plugins, themes and
uploads live in the `wordpress-html` volume and are **updated through wp-admin**, like on any
regular host. A new image never touches it (the official image only seeds an empty volume).
Changing the PHP version = changing the `FROM` tag in the Dockerfile.

The database lives in the `db-data` volume (MySQL 8.4).

Variables (defaults in `docker-compose.yaml`):

| variable           | default                                     |
|--------------------|---------------------------------------------|
| `WORDPRESS_URL`    | `https://wordpress.wpnuxt.com`              |
| `DB_NAME`, `DB_USER` | `wpnuxt`                                  |
| `DB_PASSWORD`, `DB_ROOT_PASSWORD` | required, no default             |
| `WPNUXT_REVALIDATE_URL`, `WPNUXT_REVALIDATE_SECRET` | empty (no cache purge) |

## WordPress plugins

Installed through wp-admin, so not part of this repository. What WPNuxt uses on this site:

- [WPGraphQL](https://wordpress.org/plugins/wp-graphql/): the GraphQL API WPNuxt queries (required)
- [WPGraphQL Content Blocks](https://github.com/wpengine/wp-graphql-content-blocks): Gutenberg blocks
  as data, for `@wpnuxt/blocks`
- [WPGraphQL Headless Login](https://github.com/AxeWP/wp-graphql-headless-login): login for
  `@wpnuxt/auth`
- [WPGraphQL Smart Cache](https://wordpress.org/plugins/wpgraphql-smart-cache/),
  [WPGraphQL for ACF](https://wordpress.org/plugins/wpgraphql-acf/) +
  [Advanced Custom Fields](https://wordpress.org/plugins/advanced-custom-fields/)
- [FaustWP](https://wordpress.org/plugins/faustwp/): previews and front-end URL rewriting
- `wpnuxt-demo`: the demo's custom post types and fields, from
  [`playgrounds/full/wp-plugin`](https://github.com/wpnuxt/wpnuxt/tree/main/playgrounds/full/wp-plugin)

## Frontend connection

The frontend (WPNuxt) calls `https://wordpress.wpnuxt.com/graphql` over the public hostname.
On every content change `docker/mu-plugins/wpnuxt-revalidate.php` posts `WPNUXT_REVALIDATE_SECRET`
to `WPNUXT_REVALIDATE_URL` (`https://demo.wpnuxt.com/api/_wpnuxt/revalidate`), which purges the
frontend's GraphQL cache. The secret must match the frontend's `NUXT_WP_NUXT_REVALIDATE_SECRET`.

## Run locally

```sh
cp .env.example .env        # sets COMPOSE_FILE (adds the local overrides) and the DB passwords
docker compose up -d --build
```

This starts an empty WordPress on http://localhost:8080. To start from an existing site instead:

```sh
OLD_HOST=<ssh host> OLD_PATH=<WordPress root> scripts/pull-production.sh   # into ./data/ (git-ignored)
scripts/import.sh
```

## Deploy on Coolify

1. **New Resource → this GitHub repository**, branch `main`, build pack **Docker Compose**,
   compose location `/docker-compose.yaml`.
2. **Environment variables**: fill in `DB_PASSWORD` and `DB_ROOT_PASSWORD` (e.g.
   `openssl rand -hex 32`), and `WPNUXT_REVALIDATE_URL`/`WPNUXT_REVALIDATE_SECRET` (see
   *Frontend connection*). For a test deployment on another hostname set `WORDPRESS_URL` to that
   same URL.
3. **Domain** of the `wordpress` service (Coolify sees `SERVICE_FQDN_WORDPRESS_8080`). Don't add `ports:`.
4. **Deploy.** The first deployment builds the image and seeds an empty WordPress.
5. **Load an existing site** (optional), from your machine. Container names change on every deploy:
   ```sh
   OLD_HOST=<ssh host> OLD_PATH=<WordPress root> scripts/pull-production.sh
   export DOCKER_HOST=ssh://<server>
   docker ps --format '{{.Names}}' | grep -E '^(wordpress|db)-'
   scripts/import.sh wordpress-<uuid>-<n> db-<uuid>-<n>
   ```
6. Point the DNS of the site's hostname to the server and set the domain/`WORDPRESS_URL` to it.

## After moving an existing site

- Settings → Permalinks → Save (regenerates `.htaccess`); check that `/graphql` responds.
- Login: the image generates new auth keys and salts, so everyone logs in again.
- Security and backup plugins: firewalls that the old host loaded through `.user.ini` (Wordfence)
  need their setup step again; check that the backup plugin's remote storage still works.
- `pull-production.sh` skips caches, logs, backups and `mu-plugins/` (host-specific).
