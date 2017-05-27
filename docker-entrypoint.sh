#!/bin/sh

# Environment variables:
# COLLECTD_INFLUXDB_HOST, COLLECTD_INFLUXDB_PORT=25826: influxdb configuration, hostname must be resolvable.
# COLLECTD_DOCKER_SOCKET_PATH: path to docker.sock, mount from docker host with `-v /var/run/docker.sock:/docker.sock:ro`.
# COLLECTD_HAPROXY_SOCKET_PATH: path to haproxy.sock, getting stats does not require admin level.
# COLLECTD_MEMCACHED_ADDRESS, COLLECTD_MEMCACHED_PORT, COLLECTD_MEMCACHED_SOCKET: memcached configuration.
# COLLECTD_MYSQL_USER, COLLECTD_MYSQL_PASSWORD: mysql configuration.
#	COLLECTD_MYSQL_HOST, COLLECTD_MYSQL_PORT
# 	COLLECTD_MYSQL_SOCKET
#	COLLECTD_MYSQL_MASTER_STATS, COLLECTD_MYSQL_SLAVE_STATS, COLLECTD_MYSQL_INNODB_STATS
# COLLECTD_REDIS_HOST, COLLECTD_REDIS_PASSWORD, COLLECTD_REDIS_PORT: redis configuration.
# COLLECTD_WEB_HOST, COLLECTD_WEB_PORT=80: web configuration, hostname must be resolvable.
#	COLLECTD_NGINX_STATUS_PATH: used with COLLECTD_WEB_HOST to get nginx stats (using `stub_status on;`).
#	COLLECTD_PHP_FPM_STATUS_PATH: used with COLLECTD_WEB_HOST to get php-fpm stats (using `pm.status_path = /status`).

set -e

# if command starts with an option, prepend collectd
if [ "${1:0:1}" = '-' ]; then
	set -- collectd "$@"
fi

if [ "x$1" == "xcollectd" ]; then
	_collectdConf="$( \
		echo "# Generated at `date`"; \
		echo "Hostname \"`head -n 1 /etc/hostname`\""; \
		echo "AutoLoadPlugin true"; \
		echo "TypesDB \"/usr/share/collectd/types.db\""; \
	)"

	if [ ! -z "$COLLECTD_INFLUXDB_HOST" ]; then
		_influxdbIp="$( getent hosts $COLLECTD_INFLUXDB_HOST | awk '{ print $1 }' )"
		if [ -z "$_influxdbIp" ]; then
			echo "COLLECTD_INFLUXDB_HOST ($COLLECTD_INFLUXDB_HOST) host not found."
			exit 1
		fi
		_influxdbPort=${COLLECTD_INFLUXDB_PORT:-"25826"}

		_collectdConf="$( \
			echo "$_collectdConf"; \
			echo ""; \
			echo "<Plugin \"network\">"; \
			echo "	Server \"$COLLECTD_INFLUXDB_HOST\" \"$_influxdbPort\""; \
			echo "</Plugin>"; \
		)"
	fi

	if [ ! -z "$COLLECTD_DOCKER_SOCKET_PATH" ]; then
		if [ ! -e "$COLLECTD_DOCKER_SOCKET_PATH" ]; then
			echo "COLLECTD_DOCKER_SOCKET_PATH ($COLLECTD_DOCKER_SOCKET_PATH) file not found."
			exit 1
		fi

		_collectdConf="$( \
			echo "$_collectdConf"; \
			echo ""; \
			echo "<Plugin \"python\">"; \
			echo "	ModulePath \"/plugins/docker-collectd-plugin\""; \
			echo "	Import \"dockerplugin\""; \
			echo "	<Module dockerplugin>"; \
			echo "		BaseURL \"unix:/$COLLECTD_DOCKER_SOCKET_PATH\""; \
			echo "	</Module>"; \
			echo "</Plugin>"; \
		)"
	fi

	if [ ! -z "$COLLECTD_HAPROXY_SOCKET_PATH" ]; then
		if [ ! -e "$COLLECTD_HAPROXY_SOCKET_PATH" ]; then
			echo "COLLECTD_HAPROXY_SOCKET_PATH ($COLLECTD_HAPROXY_SOCKET_PATH) file not found."
			exit 1
		fi

		_collectdConf="$( \
			echo "$_collectdConf"; \
			echo ""; \
			echo "<Plugin \"python\">"; \
			echo "	ModulePath \"/plugins/collectd-haproxy\""; \
			echo "	Import \"haproxy\""; \
			echo "	<Module haproxy>"; \
			echo "		Socket \"$COLLECTD_HAPROXY_SOCKET_PATH\""; \
			echo "		ProxyMonitor \"port80\""; \
			echo "		ProxyMonitor \"port443\""; \
			echo "	</Module>"; \
			echo "</Plugin>"; \
		)"
	fi

	if [ ! -z "$COLLECTD_MEMCACHED_ADDRESS" -o ! -z "$COLLECTD_MEMCACHED_SOCKET" ]; then
		_collectdConf="$( \
			echo "$_collectdConf"; \
			echo ""; \
			echo "<Plugin \"memcached\">"; \
		)"

		if [ ! -z "$COLLECTD_MEMCACHED_ADDRESS" ]; then
			_memcachedIp="$( getent hosts $COLLECTD_MEMCACHED_ADDRESS | awk '{ print $1 }' )"
			if [ -z "$_memcachedIp" ]; then
				echo "COLLECTD_MEMCACHED_ADDRESS ($COLLECTD_MEMCACHED_ADDRESS) host not found."
				exit 1
			fi
			_memcachedPort=${COLLECTD_MEMCACHED_PORT:-11211}

			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo "	Address \"$COLLECTD_MEMCACHED_ADDRESS\""; \
				echo "	Port \"$_memcachedPort\""; \
			)"
		elif [ ! -z "$COLLECTD_MEMCACHED_SOCKET" ]; then
			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo "	Socket \"$COLLECTD_MEMCACHED_SOCKET\""; \
			)"
		fi

		_collectdConf="$( \
			echo "$_collectdConf"; \
			echo "</Plugin>"; \
		)"
	fi

	if [ ! -z "$COLLECTD_MYSQL_USER" ]; then
		if [ -z "$COLLECTD_MYSQL_PASSWORD" ]; then
			echo 'COLLECTD_MYSQL_PASSWORD is missing'
			exit 1
		fi

		_mysqlInstance='localhost'
		if [ ! -z "$COLLECTD_MYSQL_HOST" ]; then
			_mysqlInstance="$COLLECTD_MYSQL_HOST"
		fi

		_collectdConf="$( \
			echo "$_collectdConf"; \
			echo ""; \
			echo "<Plugin \"mysql\">"; \
			echo "	<Database \"$_mysqlInstance\">"; \
			echo "		User \"$COLLECTD_MYSQL_USER\""; \
			echo "		Password \"$COLLECTD_MYSQL_PASSWORD\""; \
		)"

		if [ ! -z "$COLLECTD_MYSQL_HOST" ]; then
			_mysqlIp="$( getent hosts $COLLECTD_MYSQL_HOST | awk '{ print $1 }' )"
			if [ -z "$_mysqlIp" ]; then
				echo "COLLECTD_MYSQL_HOST ($COLLECTD_MYSQL_HOST) host not found."
				exit 1
			fi
			_mysqlPort=${COLLECTD_MYSQL_PORT:-3306}

			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo "		Host \"$COLLECTD_MYSQL_HOST\""; \
				echo "		Port \"$_mysqlPort\""; \
			)"
		elif [ ! -z "$COLLECTD_MYSQL_SOCKET" ]; then
			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo "		Socket \"$COLLECTD_MYSQL_SOCKET\""; \
			)"
		fi

		if [ ! -z "$COLLECTD_MYSQL_MASTER_STATS" ]; then
			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo "		MasterStats true"; \
			)"
		fi

		if [ ! -z "$COLLECTD_MYSQL_SLAVE_STATS" ]; then
			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo "		SlaveStats true"; \
			)"
		fi

		if [ ! -z "$COLLECTD_MYSQL_INNODB_STATS" ]; then
			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo "		InnodbStats true"; \
			)"
		fi

		_collectdConf="$( \
			echo "$_collectdConf"; \
			echo "	</Database>"; \
			echo "</Plugin>"; \
		)"
	fi

	if [ ! -z "$COLLECTD_REDIS_HOST" ]; then
		_redisIp="$( getent hosts $COLLECTD_REDIS_HOST | awk '{ print $1 }' )"
		if [ -z "$_redisIp" ]; then
			echo "COLLECTD_REDIS_HOST ($COLLECTD_REDIS_HOST) host not found."
			exit 1
		fi
		_redisPort=${COLLECTD_REDIS_PORT:-6379}

		_collectdConf="$( \
			echo "$_collectdConf"; \
			echo ""; \
			echo "<Plugin \"redis\">"; \
			echo "	<Node \"$COLLECTD_REDIS_HOST\">"; \
			echo "		Host \"$COLLECTD_REDIS_HOST\""; \
			echo "		Port \"$_redisPort\""; \
		)"

		if [ ! -z "$COLLECTD_REDIS_PASSWORD" ]; then
			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo "		Password \"$COLLECTD_REDIS_PASSWORD\""; \
			)"
		fi

		_collectdConf="$( \
			echo "$_collectdConf"; \
			echo "	</Node>"; \
			echo "</Plugin>"; \
		)"
	fi

	if [ ! -z "$COLLECTD_WEB_HOST" ]; then
		_webIp="$( getent hosts $COLLECTD_WEB_HOST | awk '{ print $1 }' )"
		if [ -z "$_webIp" ]; then
			echo "COLLECTD_WEB_HOST ($COLLECTD_WEB_HOST) host not found."
			exit 1
		fi
		_webPort=${COLLECTD_WEB_PORT:-"80"}

		if [ ! -z "$COLLECTD_NGINX_STATUS_PATH" ]; then
			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo ""; \
				echo "<Plugin \"nginx\">"; \
				echo "	URL \"http://$COLLECTD_WEB_HOST:$_webPort$COLLECTD_NGINX_STATUS_PATH\""; \
				echo "</Plugin>"; \
			)"
		fi

		if [ ! -z "$COLLECTD_PHP_FPM_STATUS_PATH" ]; then
			_collectdConf="$( \
				echo "$_collectdConf"; \
				echo ""; \
				echo "<Plugin curl_json>"; \
				echo "	<URL \"http://$COLLECTD_WEB_HOST:$_webPort$COLLECTD_PHP_FPM_STATUS_PATH?json\">"; \
				echo "		Instance 'main'"; \
				echo "		<Key \"accepted conn\">"; \
				echo "			Type \"phpfpm_requests\""; \
				echo "			Instance \"\""; \
				echo "		</Key>"; \
				echo "		<Key \"slow requests\">"; \
				echo "			Type \"phpfpm_slow_requests\""; \
				echo "			Instance \"\""; \
				echo "		</Key>"; \
				echo "		<Key \"listen queue\">"; \
				echo "			Type \"phpfpm_listen_queue\""; \
				echo "			Instance \"\""; \
				echo "		</Key>"; \
				echo "		<Key \"active processes\">"; \
				echo "			Type \"phpfpm_processes\""; \
				echo "			Instance \"active\""; \
				echo "		</Key>"; \
				echo "		<Key \"total processes\">"; \
				echo "			Type \"phpfpm_processes\""; \
				echo "			Instance \"total\""; \
				echo "		</Key>"; \
				echo "	</URL>"; \
				echo "</Plugin>"; \
			)"
		fi
	fi

	echo "$_collectdConf" | tee "/etc/collectd/collectd.conf"
fi

echo "Executing $@..."
exec "$@"