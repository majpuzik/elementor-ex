<?php
/* Vlož do wp-config.php PŘED "That's all, stop editing".
   HTTPS terminuje cloudflared/proxy → forwarduje http + X-Forwarded-Proto.
   Bez tohohle WP generuje http:// URL a dělá redirect-loop. */

if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
if (isset($_SERVER['HTTP_X_FORWARDED_HOST'])) {
    $_SERVER['HTTP_HOST'] = $_SERVER['HTTP_X_FORWARDED_HOST'];
}
define('WP_HOME',    'https://SUBDOMAIN.example.eu');
define('WP_SITEURL', 'https://SUBDOMAIN.example.eu');

/* DB = kontejner (service name z docker-compose) */
// define('DB_HOST', 'SITE-db:3306');
