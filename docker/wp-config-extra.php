<?php
/**
 * Extra wp-config.php settings, loaded through WORDPRESS_CONFIG_EXTRA (docker-compose.yaml).
 */

// TLS ends at the reverse proxy; tell WordPress the visitor used https
if ( isset( $_SERVER['HTTP_X_FORWARDED_PROTO'] ) && 'https' === $_SERVER['HTTP_X_FORWARDED_PROTO'] ) {
	$_SERVER['HTTPS'] = 'on';
}

// The site URL comes from the environment, so the same database works on localhost and in production
$site_url = rtrim( getenv( 'WORDPRESS_URL' ) ?: 'https://wordpress.wpnuxt.com', '/' );
define( 'WP_HOME', $site_url );
define( 'WP_SITEURL', $site_url );
define( 'FORCE_SSL_ADMIN', str_starts_with( $site_url, 'https://' ) );
unset( $site_url );

// Hardening: no code editing from wp-admin, automatic minor core updates
define( 'DISALLOW_FILE_EDIT', true );
define( 'CONCATENATE_SCRIPTS', false );
define( 'WP_AUTO_UPDATE_CORE', 'minor' );

