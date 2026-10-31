# Same PHP version as the old host; the WordPress version in the image is only used
# to seed an empty volume, afterwards it updates itself from wp-admin.
FROM wordpress:php8.5-apache@sha256:63eda59d220083d9ed1fd9685ffdd5e0405959fd2fec73a734b631487561e12f

# Real visitor IPs behind the Coolify (Traefik) reverse proxy, needed by Wordfence & co.
COPY docker/remoteip.conf /etc/apache2/conf-available/remoteip.conf
RUN a2enmod remoteip && a2enconf remoteip

COPY docker/php.ini /usr/local/etc/php/conf.d/wpnuxt.ini
COPY docker/wp-config-extra.php /usr/local/etc/wordpress/config-extra.php

# mu-plugins (docker/mu-plugins/), copied into the volume on every start by entrypoint.sh
COPY docker/mu-plugins/ /usr/local/share/wordpress-mu-plugins/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Run as www-data instead of root; docker-compose.yaml lets unprivileged users bind port 80 (sysctls)
USER www-data

ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2-foreground"]
