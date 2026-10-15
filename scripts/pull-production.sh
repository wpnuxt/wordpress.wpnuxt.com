#!/usr/bin/env bash
# Copy a live WordPress site from its current host into ./data/ (git-ignored):
#   data/wp-content/   plugins, themes, uploads, languages, ... (caches, logs and backups excluded)
#   data/db.sql.gz     dump of the wp_* tables
# Database credentials are read from wp-config.php on the server and never leave it.
# Safe to re-run: rsync only transfers what changed. (--stats instead of a progress bar:
# macOS ships openrsync, which has no --info=progress2.)
#
#   OLD_HOST=<ssh host> OLD_PATH=<WordPress root on that host> scripts/pull-production.sh
#
# Needs ssh access with rsync, mysql and mysqldump on the old host.
set -euo pipefail

host="${OLD_HOST:?set OLD_HOST to the ssh host of the current site}"
remote="${OLD_PATH:?set OLD_PATH to the WordPress root (the folder with wp-config.php) on that host}"
data="$(cd "$(dirname "$0")/.." && pwd)/data"
mkdir -p "$data"

echo "==> wp-content  ->  $data/wp-content"
# The leading / anchors each pattern to wp-content/ itself; without it "upgrade/" would also
# drop plugin code such as a plugin's own classes/upgrade/ folder.
rsync -az --delete --stats \
  --exclude '/cache/' \
  --exclude '/wflogs/' \
  --exclude '/upgrade/' \
  --exclude '/upgrade-temp-backup/' \
  --exclude '/updraft/' \
  --exclude '/backwpup-*/' \
  --exclude '/infinitewp/' \
  --exclude '/jetpack-waf/' \
  --exclude '/rsssl-managed-htaccess.lock' \
  --exclude '/maintenance/' \
  --exclude '/mu-plugins/' \
  --exclude '/uploads/cache/' \
  --exclude '/uploads/backwpup/' \
  --exclude '/uploads/iwp_*/' \
  "$host:$remote/wp-content/" "$data/wp-content/"

echo "==> database  ->  $data/db.sql.gz"
ssh "$host" bash -s "$remote" > "$data/db.sql.gz" <<'REMOTE'
set -euo pipefail
cd "$1"
cfg() { sed -n "s/^define( *['\"]$1['\"], *['\"]\([^'\"]*\)['\"] *);.*/\1/p" wp-config.php; }
export MYSQL_PWD="$(cfg DB_PASSWORD)"
conn=(-h "$(cfg DB_HOST)" -u "$(cfg DB_USER)")
db="$(cfg DB_NAME)"
# only the site's own tables
tables=$(mysql "${conn[@]}" -N -e "SHOW TABLES FROM \`$db\` LIKE 'wp\\_%'")
# shellcheck disable=SC2086
mysqldump "${conn[@]}" --single-transaction --quick --no-tablespaces --set-gtid-purged=OFF \
  --default-character-set=utf8mb4 "$db" $tables | gzip
REMOTE

echo "==> done"
du -sh "$data/wp-content" "$data/db.sql.gz"
