#!/usr/bin/env php
<?php

include '/srv/ttrss-utils.php';

$confpath = env('TTRSS_PATH', '/var/www/ttrss');
$conffile = $confpath . '/config.php';

$ename = 'DB';
$eport = 5432;

$db_type = env('DB_TYPE','pgsql');
if ($db_type == 'mysql'){
    $eport = 3306;
}

echo 'Configuring database for: ' . $conffile . PHP_EOL;

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

if (!dbcheck($config)) {
    echo 'Database login failed, trying to create ...' . PHP_EOL;
    // superuser account to create new database and corresponding user account
    //   username (SU_USER) can be supplied or defaults to "docker"
    //   password (SU_PASS) can be supplied or defaults to username

    $super = $config;

    $super['DB_NAME'] = null;
    $super['DB_USER'] = env($ename . '_ENV_USER', 'docker');
    $super['DB_PASS'] = env($ename . '_ENV_PASS', $super['DB_USER']);

    $pdo = dbconnect($super);
    $pdo->exec('CREATE ROLE ' . ($config['DB_USER']) . ' WITH LOGIN PASSWORD ' . $pdo->quote($config['DB_PASS']));
    $pdo->exec('CREATE DATABASE ' . ($config['DB_NAME']) . ' WITH OWNER ' . ($config['DB_USER']));
    unset($pdo);

    if (dbcheck($config)) {
        echo 'Database login created and confirmed' . PHP_EOL;
    } else {
        error('Database login failed, trying to create login failed as well');
    }
}

$pdo = dbconnect($config);
try {
    $pdo->query('SELECT 1 FROM ttrss_feeds');
    echo 'Connection to database successful' . PHP_EOL;
    // Reached this point => table found, assume db is complete

    if (env('TTRSS_THEME_RESET', '1')) {
        // Make sure to set the default theme provided by TT-RSS.
        // Other themes might break everything after an update, so play safe here.
        echo 'Resetting theme to default ...' . PHP_EOL;
        $pdo->query("UPDATE ttrss_user_prefs SET value = '' WHERE pref_name = 'USER_CSS_THEME'");
    }
}
catch (PDOException $e) {
    echo 'Database table not found, applying schema... ' . PHP_EOL;

    $schema = file_get_contents($confpath . '/schema/ttrss_schema_' . $config['DB_TYPE'] . '.sql');
    $schema = preg_replace('/--(.*?);/', '', $schema);
    $schema = preg_replace('/[\r\n]/', ' ', $schema);
    $schema = trim($schema, ' ;');
    foreach (explode(';', $schema) as $stm) {
        $pdo->exec($stm);
    }
    unset($pdo);
}

$contents = file_get_contents($conffile);
foreach ($config as $name => $value) {
    $contents .= "putenv('TTRSS_" . $name . "=" . $value . "');\n";
}
file_put_contents($conffile, $contents);
