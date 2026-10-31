#!/bin/sh
# Installs the mu-plugins shipped with the image into the wordpress-html volume
# (which otherwise only changes through wp-admin), then starts WordPress as usual.
set -e

mkdir -p /var/www/html/wp-content/mu-plugins
cp /usr/local/share/wordpress-mu-plugins/*.php /var/www/html/wp-content/mu-plugins/

exec docker-entrypoint.sh "$@"
