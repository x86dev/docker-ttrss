#!/usr/bin/env php
<?php

include '/srv/ttrss-utils.php';

$ename = 'DB';
$eport = 5432;

$db_type = env('DB_TYPE','pgsql');
if ($db_type == 'mysql'){
    $eport = 3306;
}
$confpath = '/var/www/ttrss/config.php';

// check DB_NAME, which will be set automatically for a linked "db" container
if (!env($ename . '_PORT', '')) {
    error('The env ' . $ename .'_PORT does not exist. Make sure to run with "--link mypostgresinstance:' . $ename . '"');
}

$config = array();
$config['DB_TYPE'] = $db_type;
$config['DB_HOST'] = env($ename . '_PORT_' . $eport . '_TCP_ADDR');
$config['DB_PORT'] = env($ename . '_PORT_' . $eport . '_TCP_PORT');

// database credentials for this instance
//   database name (DB_NAME) can be supplied or detaults to "ttrss"
//   database user (DB_USER) can be supplied or defaults to database name
//   database pass (DB_PASS) can be supplied or defaults to database user
$config['DB_NAME'] = env($ename . '_NAME', 'ttrss');
$config['DB_USER'] = env($ename . '_USER', $config['DB_NAME']);
$config['DB_PASS'] = env($ename . '_PASS', $config['DB_USER']);

$pdo = dbconnect($config);
try {
    $pdo->query('SELECT 1 FROM plugin_mobilize_feeds');
    // reached this point => table found, assume db is complete
}
catch (PDOException $e) {
    echo 'Database table for mobilize plugin not found, applying schema... ' . PHP_EOL;
    $schema = file_get_contents('/srv/ttrss-plugin-mobilize.'.$db_type);
    $schema = preg_replace('/--(.*?);/', '', $schema);
    $schema = preg_replace('/[\r\n]/', ' ', $schema);
    $schema = trim($schema, ' ;');
    foreach (explode(';', $schema) as $stm) {
        $pdo->exec($stm);
    }
    unset($pdo);
}

$contents = file_get_contents($confpath);
foreach ($config as $name => $value) {
    $contents = preg_replace('/(define\s*\(\'' . $name . '\',\s*)(.*)(\);)/', '$1"' . $value . '"$3', $contents);
}
file_put_contents($confpath, $contents);
