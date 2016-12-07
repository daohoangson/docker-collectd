#!/bin/sh

# Environment variables:
# COLLECTD_INFLUXDB_HOST, COLLECTD_INFLUXDB_PORT=25826: influxdb configuration, hostname must be resolvable.
# COLLECTD_DOCKER_SOCKET_PATH: path to docker.sock, mount from docker host with `-v /var/run/docker.sock:/docker.sock:ro`.
# COLLECTD_HAPROXY_SOCKET_PATH: path to haproxy.sock, getting stats does not require admin level.
# COLLECTD_WEB_HOST, COLLECTD_WEB_PORT=80: web configuration, hostname must be resolvable.
#	COLLECTD_NGINX_STATUS_PATH: used with COLLECTD_WEB_HOST to get nginx stats (using `stub_status on;`).
#	COLLECTD_PHP_FPM_STATUS_PATH: used with COLLECTD_WEB_HOST to get php-fpm stats (using `pm.status_path = /status`).

set -e

# if command starts with an option, prepend collectd
if [ "${1:0:1}" = "-" ]; then
	set -- collectd "$@"
fi

if [ "x$1" == "xcollectd" ]; then
	GENERATED_DATE="$( date )"
	HOSTNAME="$( head -n 1 "/etc/hostname" )"
	COLLECTD_CONF="$( \
		echo "# Generated at $GENERATED_DATE"; \
		echo "Hostname \"$HOSTNAME\""; \
		echo "AutoLoadPlugin true"; \
		echo "TypesDB \"/usr/share/collectd/types.db\""; \
	)"

	if [ ! -z "$COLLECTD_INFLUXDB_HOST" ]; then
		IP="$( getent hosts $COLLECTD_INFLUXDB_HOST | awk '{ print $1 }' )"
		if [ "x$IP" == "x" ]; then
			echo "COLLECTD_INFLUXDB_HOST ($COLLECTD_INFLUXDB_HOST) host not found."
			exit 1
		fi
		COLLECTD_INFLUXDB_PORT=${COLLECTD_INFLUXDB_PORT:-"25826"}

		COLLECTD_CONF="$( \
			echo "$COLLECTD_CONF"; \
			echo ""; \
			echo "<Plugin \"network\">"; \
			echo "	Server \"$COLLECTD_INFLUXDB_HOST\" \"COLLECTD_INFLUXDB_PORT\""; \
			echo "</Plugin>"; \
		)"
	fi

	if [ ! -z "$COLLECTD_DOCKER_SOCKET_PATH" ]; then
		if [ ! -f "$COLLECTD_DOCKER_SOCKET_PATH" ]; then
			echo "COLLECTD_DOCKER_SOCKET_PATH ($COLLECTD_DOCKER_SOCKET_PATH) file not found."
			exit 1
		fi

		COLLECTD_CONF="$( \
			echo "$COLLECTD_CONF"; \
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
		if [ ! -f "$COLLECTD_HAPROXY_SOCKET_PATH" ]; then
			echo "COLLECTD_HAPROXY_SOCKET_PATH ($COLLECTD_HAPROXY_SOCKET_PATH) file not found."
			exit 1
		fi

		COLLECTD_CONF="$( \
			echo "$COLLECTD_CONF"; \
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

	if [ ! -z "$COLLECTD_WEB_HOST" ]; then
		IP="$( getent hosts $COLLECTD_WEB_HOST | awk '{ print $1 }' )"
		if [ "x$IP" == "x" ]; then
			echo "COLLECTD_WEB_HOST ($COLLECTD_WEB_HOST) host not found."
			exit 1
		fi
		COLLECTD_WEB_PORT=${COLLECTD_WEB_PORT:-"80"}

		if [ ! -z "$COLLECTD_NGINX_STATUS_PATH" ]; then
			COLLECTD_CONF="$( \
				echo "$COLLECTD_CONF"; \
				echo ""; \
				echo "<Plugin \"nginx\">"; \
				echo "	URL \"http://$COLLECTD_WEB_HOST:$COLLECTD_WEB_PORT/$COLLECTD_NGINX_STATUS_PATH\""; \
				echo "</Plugin>"; \
			)"
		fi

		if [ ! -z "$COLLECTD_PHP_FPM_STATUS_PATH" ]; then
			COLLECTD_CONF="$( \
				echo "$COLLECTD_CONF"; \
				echo ""; \
				echo "<Plugin curl_json>"; \
				echo "	<URL \"http://$COLLECTD_WEB_HOST:$COLLECTD_WEB_PORT/$COLLECTD_PHP_FPM_STATUS_PATH?json\">"; \
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

	echo "$COLLECTD_CONF" | tee "/etc/collectd/collectd.conf" >&0
	echo "$COLLECTD_CONF"
fi

echo "Executing $@..."
exec "$@"