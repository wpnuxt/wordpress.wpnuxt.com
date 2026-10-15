<?php
/**
 * Plugin Name: WPNuxt revalidate
 * Description: Purges the WPNuxt (Nitro) GraphQL cache of the frontend when content changes.
 *
 * Configured through the environment (docker-compose.yaml); does nothing when either is empty:
 *   WPNUXT_REVALIDATE_URL     e.g. https://demo.wpnuxt.com/api/_wpnuxt/revalidate
 *   WPNUXT_REVALIDATE_SECRET  same value as the frontend's revalidate secret
 *
 * Installed by the image (docker/entrypoint.sh copies it into wp-content/mu-plugins).
 */

defined( 'ABSPATH' ) || exit;

function wpnuxt_revalidate_schedule() {
	$GLOBALS['wpnuxt_revalidate_pending'] = true;
}

// One purge per request, however many posts, terms or menu items changed
add_action( 'shutdown', function () {
	$url    = getenv( 'WPNUXT_REVALIDATE_URL' );
	$secret = getenv( 'WPNUXT_REVALIDATE_SECRET' );
	if ( empty( $GLOBALS['wpnuxt_revalidate_pending'] ) || ! $url || ! $secret ) {
		return;
	}
	$response = wp_remote_post( $url, array(
		'timeout' => 5,
		'headers' => array( 'Content-Type' => 'application/json' ),
		'body'    => wp_json_encode( array( 'secret' => $secret ) ),
	) );
	if ( is_wp_error( $response ) || 200 !== wp_remote_retrieve_response_code( $response ) ) {
		error_log( 'WPNuxt revalidate failed: ' . ( is_wp_error( $response ) ? $response->get_error_message() : wp_remote_retrieve_response_code( $response ) ) );
	}
} );

add_action( 'transition_post_status', function ( $new_status, $old_status, $post ) {
	if ( wp_is_post_revision( $post ) || wp_is_post_autosave( $post ) ) {
		return;
	}
	if ( 'publish' === $new_status || 'publish' === $old_status ) {
		wpnuxt_revalidate_schedule();
	}
}, 10, 3 );

add_action( 'post_updated', function ( $post_id, $post_after, $post_before ) {
	if ( 'publish' === $post_after->post_status && ! wp_is_post_revision( $post_id ) ) {
		wpnuxt_revalidate_schedule();
	}
}, 10, 3 );

foreach ( array( 'deleted_post', 'edited_term', 'created_term', 'delete_term', 'wp_update_nav_menu', 'acf/save_post', 'update_option_blogname', 'update_option_blogdescription' ) as $hook ) {
	add_action( $hook, 'wpnuxt_revalidate_schedule' );
}
