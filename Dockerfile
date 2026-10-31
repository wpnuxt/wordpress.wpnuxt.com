# Same PHP version as the old host; the WordPress version in the image is only used
# to seed an empty volume, afterwards it updates itself from wp-admin.
FROM wordpress:php8.5-apache

# Real visitor IPs behind the Coolify (Traefik) reverse proxy, needed by Wordfence & co.
COPY docker/remoteip.conf /etc/apache2/conf-available/remoteip.conf
RUN a2enmod remoteip && a2enconf remoteip

COPY docker/php.ini /usr/local/etc/php/conf.d/wpnuxt.ini
COPY docker/wp-config-extra.php /usr/local/etc/wordpress/config-extra.php

# mu-plugins (docker/mu-plugins/), copied into the volume on every start by entrypoint.sh
COPY docker/mu-plugins/ /usr/local/share/wordpress-mu-plugins/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Run as www-data instead of root; an unprivileged user can't bind port 80, so Apache listens on 8080.
RUN sed -i 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
 && sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf
USER www-data
EXPOSE 8080

ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2-foreground"]
