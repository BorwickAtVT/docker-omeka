#!/bin/bash
set -e

if [ -z "$MYSQL_PORT_3306_TCP" ]; then
	echo >&2 'error: missing MYSQL_PORT_3306_TCP environment variable'
	echo >&2 '  Did you forget to --link some_mysql_container:mysql ?'
	exit 1
fi

# if we're linked to MySQL, and we're using the root user, and our linked
# container has a default "root" password set up and passed through... :)
: ${OMEKA_DB_USER:=root}
if [ "$OMEKA_DB_USER" = 'root' ]; then
	: ${OMEKA_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
fi
: ${OMEKA_DB_NAME:=omeka}

if [ -z "$OMEKA_DB_PASSWORD" ]; then
	echo >&2 'error: missing required OMEKA_DB_PASSWORD environment variable'
	echo >&2 '  Did you forget to -e OMEKA_DB_PASSWORD=... ?'
	echo >&2
	echo >&2 '  (Also of interest might be OMEKA_DB_USER and OMEKA_DB_NAME.)'
	exit 1
fi

if ! [ -e index.php ]; then
	echo >&2 "Omeka not found in $(pwd) - copying now..."
	if [ "$(ls -A)" ]; then
		echo >&2 "WARNING: $(pwd) is not empty - press Ctrl+C now if this is an error!"
		( set -x; ls -A; sleep 10 )
	fi
	rsync --archive --one-file-system --quiet /usr/src/omeka/ ./
	echo >&2 "Complete! Omeka has been successfully copied to $(pwd)"
fi

# TODO handle Omeka upgrades magically

set_config() {
	key="$1"
	value="$2"
	sed_escaped_value="$(echo "$value" | sed 's/[\/&]/\\&/g')"

	sed -ri "s/^$key.*/$key = \"$value\"/" db.ini
	# sed -ri "s/((['\"])$key\2\s*,\s*)(['\"]).*\3/\1$sed_escaped_value/" wp-config.php
}

OMEKA_DB_HOST='mysql'

set_config 'host' "$OMEKA_DB_HOST"
set_config 'username' "$OMEKA_DB_USER"
set_config 'password' "$OMEKA_DB_PASSWORD"
set_config 'dbname' "$OMEKA_DB_NAME"

TERM=dumb php -- "$OMEKA_DB_HOST" "$OMEKA_DB_USER" "$OMEKA_DB_PASSWORD" "$OMEKA_DB_NAME" <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)

$stderr = fopen('php://stderr', 'w');

list($host, $port) = explode(':', $argv[1], 2);

$maxTries = 10;
do {
	$mysql = new mysqli($host, $argv[2], $argv[3], '', (int)$port);
	if ($mysql->connect_error) {
		fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
		--$maxTries;
		if ($maxTries <= 0) {
			exit(1);
		}
		sleep(3);
	}
} while ($mysql->connect_error);

if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
	fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
}

$mysql->close();
EOPHP

chown -R www-data:www-data .

exec "$@"
