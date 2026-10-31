#!/usr/bin/env bash
# Load ./data/ (from pull-production.sh) into a running stack.
#
#   scripts/import.sh                                    local stack (default container names)
#   scripts/import.sh wordpress-<uuid>-<n> db-<uuid>-<n>   containers of the Coolify deployment
#
# To seed the Coolify deployment straight from this machine, point the Docker CLI at the
# server the app runs on (see README.md):
#   DOCKER_HOST=ssh://<server> scripts/import.sh wordpress-<uuid>-<n> db-<uuid>-<n>
set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"
wp="${1:-wpnuxt-wordpress-wordpress-1}"
db="${2:-wpnuxt-wordpress-db-1}"

[ -d data/wp-content ] && [ -s data/db.sql.gz ] || { echo "No data/ found: run scripts/pull-production.sh first" >&2; exit 1; }

echo "==> wp-content  ->  $wp:/var/www/html/wp-content"
docker cp data/wp-content/. "$wp:/var/www/html/wp-content/"
docker exec -u root "$wp" chown -R www-data:www-data /var/www/html/wp-content

echo "==> database  ->  $db"
gunzip -c data/db.sql.gz | docker exec -i "$db" sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" exec mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"'

echo "==> done: $(docker exec "$db" sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE" -N -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()"') tables imported"
