#!/bin/sh

# Environment variables:
# COLLECTD_INFLUXDB_HOST, COLLECTD_INFLUXDB_PORT=25826: influxdb configuration, hostname must be resolvable.
# COLLECTD_DOCKER_SOCKET_PATH: path to docker.sock, mount from docker host with `-v /var/run/docker.sock:/docker.sock:ro`.
# COLLECTD_ELASTICSEARCH_HOST, COLLECTD_ELASTICSEARCH_PORT: elasticsearch configuration.
# COLLECTD_HAPROXY_SOCKET_PATH: path to haproxy.sock, getting stats does not require admin level.
# COLLECTD_MEMCACHED_HOST, COLLECTD_MEMCACHED_PORT, COLLECTD_MEMCACHED_SOCKET: memcached configuration.
# COLLECTD_MYSQL_USER, COLLECTD_MYSQL_PASSWORD: mysql configuration.
#  COLLECTD_MYSQL_HOST, COLLECTD_MYSQL_PORT
#   COLLECTD_MYSQL_SOCKET
#  COLLECTD_MYSQL_MASTER_STATS, COLLECTD_MYSQL_SLAVE_STATS, COLLECTD_MYSQL_INNODB_STATS
# COLLECTD_REDIS_HOST, COLLECTD_REDIS_PASSWORD, COLLECTD_REDIS_PORT: redis configuration.
# COLLECTD_WEB_HOST, COLLECTD_WEB_PORT=80: web configuration, hostname must be resolvable.
#  COLLECTD_NGINX_STATUS_PATH: used with COLLECTD_WEB_HOST to get nginx stats (using `stub_status on;`).
#  COLLECTD_PHP_FPM_STATUS_PATH: used with COLLECTD_WEB_HOST to get php-fpm stats (using `pm.status_path = /status`).

set -e

# if command starts with an option, prepend collectd
if [ "${1:0:1}" = '-' ]; then
  set -- collectd "$@"
fi

if [ "x$1" == "xcollectd" ]; then
  _hostname=$( hostname -s )

  _collectdConf="$( \
    echo "# Generated at `date`"; \
    echo "Hostname \"$_hostname\""; \
    echo "AutoLoadPlugin true"; \
    echo "TypesDB \"/usr/share/collectd/types.db\""; \
  )"

  if [ ! -z "$COLLECTD_INFLUXDB_HOST" ]; then
    _influxdbIp="$( getent hosts $COLLECTD_INFLUXDB_HOST | awk '{ print $1 }' )"
    _influxdbPort=${COLLECTD_INFLUXDB_PORT:-"25826"}
    if [ -z "$_influxdbIp" ]; then
      echo "COLLECTD_INFLUXDB_HOST ($COLLECTD_INFLUXDB_HOST) host not found." >&2
    else
      _collectdConf="$( \
        echo "$_collectdConf"; \
        echo ""; \
        echo "<Plugin \"network\">"; \
        echo "  Server \"$COLLECTD_INFLUXDB_HOST\" \"$_influxdbPort\""; \
        echo "</Plugin>"; \
      )"
    fi
  fi

  if [ ! -z "$COLLECTD_DOCKER_SOCKET_PATH" ]; then
    if [ ! -e "$COLLECTD_DOCKER_SOCKET_PATH" ]; then
      echo "COLLECTD_DOCKER_SOCKET_PATH ($COLLECTD_DOCKER_SOCKET_PATH) file not found." >&2
    else
      _collectdConf="$( \
        echo "$_collectdConf"; \
        echo ""; \
        echo "<Plugin \"python\">"; \
        echo "  ModulePath \"/plugins/docker-collectd-plugin\""; \
        echo "  Import \"dockerplugin\""; \
        echo "  <Module dockerplugin>"; \
        echo "    BaseURL \"unix:/$COLLECTD_DOCKER_SOCKET_PATH\""; \
        echo "  </Module>"; \
        echo "</Plugin>"; \
      )"
    fi
  fi

  if [ ! -z "$COLLECTD_ELASTICSEARCH_HOST" ]; then
    _elasticsearchIp="$( getent hosts $COLLECTD_ELASTICSEARCH_HOST | awk '{ print $1 }' )"
    _elasticsearchPort=${COLLECTD_ELASTICSEARCH_PORT:-9200}
    if [ -z "$_elasticsearchIp" ]; then
      echo "COLLECTD_ELASTICSEARCH_HOST ($COLLECTD_ELASTICSEARCH_HOST) host not found." >&2
    else
      _collectdConf="$( \
        echo "$_collectdConf"; \
        echo ""; \
        echo "<Plugin \"python\">"; \
        echo "  ModulePath \"/plugins/collectd-elasticsearch\""; \
        echo "  Import \"elasticsearch_collectd\""; \
        echo "  <Module elasticsearch_collectd>"; \
        echo "    Host \"$_elasticsearchIp\""; \
        echo "    Port \"$_elasticsearchPort\""; \
        echo "    EnableClusterHealth true"; \
        echo "    EnableIndexStats true"; \
        echo "    Indexes [\"_all\"]"; \
        echo "    IndexStatsMasterOnly true"; \
        echo "  </Module>"; \
        echo "</Plugin>"; \
      )"
    fi
  fi

  if [ ! -z "$COLLECTD_HAPROXY_SOCKET_PATH" ]; then
    if [ ! -e "$COLLECTD_HAPROXY_SOCKET_PATH" ]; then
      echo "COLLECTD_HAPROXY_SOCKET_PATH ($COLLECTD_HAPROXY_SOCKET_PATH) file not found." >&2
    else
      _collectdConf="$( \
        echo "$_collectdConf"; \
        echo ""; \
        echo "<Plugin \"python\">"; \
        echo "  ModulePath \"/plugins/collectd-haproxy\""; \
        echo "  Import \"haproxy\""; \
        echo "  <Module haproxy>"; \
        echo "    Socket \"$COLLECTD_HAPROXY_SOCKET_PATH\""; \
        echo "    ProxyMonitor \"port80\""; \
        echo "    ProxyMonitor \"port443\""; \
        echo "  </Module>"; \
        echo "</Plugin>"; \
      )"
    fi
  fi

  if [ ! -z "$COLLECTD_MEMCACHED_HOST" ]; then
    _memcachedIp="$( getent hosts $COLLECTD_MEMCACHED_HOST | awk '{ print $1 }' )"
    _memcachedPort=${COLLECTD_MEMCACHED_PORT:-11211}
    if [ -z "$_memcachedIp" ]; then
      echo "COLLECTD_MEMCACHED_HOST ($COLLECTD_MEMCACHED_HOST) host not found." >&2
    else
      _collectdConf="$( \
        echo "$_collectdConf"; \
        echo ""; \
        echo "<Plugin \"memcached\">"; \
        echo "  <Instance \"$_hostname\">"; \
        echo "    Host \"$COLLECTD_MEMCACHED_HOST\""; \
        echo "    Port \"$_memcachedPort\""; \
        echo "  </Instance>"; \
        echo "</Plugin>"; \
      )"
    fi
  elif [ ! -z "$COLLECTD_MEMCACHED_SOCKET" ]; then
    if [ ! -e "$COLLECTD_MEMCACHED_SOCKET" ]; then
      echo "COLLECTD_MEMCACHED_SOCKET ($COLLECTD_MEMCACHED_SOCKET) file not found." >&2
    else
      _collectdConf="$( \
        echo "$_collectdConf"; \
        echo ""; \
        echo "<Plugin \"memcached\">"; \
        echo "  <Instance \"$_hostname\">"; \
        echo "    Socket \"$COLLECTD_MEMCACHED_SOCKET\""; \
        echo "  </Instance>"; \
        echo "</Plugin>"; \
      )"
    fi
  fi

  if [ ! -z "$COLLECTD_MYSQL_USER" -a ! -z "$COLLECTD_MYSQL_PASSWORD" ]; then
    _mysqlConf="$( \
      echo "    User \"$COLLECTD_MYSQL_USER\""; \
      echo "    Password \"$COLLECTD_MYSQL_PASSWORD\""; \
    )"

    if [ ! -z "$COLLECTD_MYSQL_MASTER_STATS" ]; then
      _mysqlConf="$( \
        echo "$_collectdConf"; \
        echo "    MasterStats true"; \
      )"
    fi

    if [ ! -z "$COLLECTD_MYSQL_SLAVE_STATS" ]; then
      _mysqlConf="$( \
        echo "$_collectdConf"; \
        echo "    SlaveStats true"; \
      )"
    fi

    if [ ! -z "$COLLECTD_MYSQL_INNODB_STATS" ]; then
      _mysqlConf="$( \
        echo "$_mysqlConf"; \
        echo "    InnodbStats true"; \
      )"
    fi

    if [ ! -z "$COLLECTD_MYSQL_HOST" ]; then
      _mysqlIp="$( getent hosts $COLLECTD_MYSQL_HOST | awk '{ print $1 }' )"
      _mysqlPort=${COLLECTD_MYSQL_PORT:-3306}
      if [ -z "$_mysqlIp" ]; then
        echo "COLLECTD_MYSQL_HOST ($COLLECTD_MYSQL_HOST) host not found." >&2
      else
        _collectdConf="$( \
          echo "$_collectdConf"; \
          echo; \
          echo "<Plugin \"mysql\">"; \
          echo "  <Database \"$COLLECTD_MYSQL_HOST\">"; \
          echo "    Host \"$COLLECTD_MYSQL_HOST\""; \
          echo "    Port \"$_mysqlPort\""; \
          echo "$_mysqlConf"; \
          echo "  </Database>"; \
          echo "</Plugin>"; \
        )"
      fi
    elif [ ! -z "$COLLECTD_MYSQL_SOCKET" ]; then
      if [ ! -e "$COLLECTD_MYSQL_SOCKET" ]; then
        echo "COLLECTD_MYSQL_SOCKET ($COLLECTD_MYSQL_SOCKET) file not found." >&2
      else
        _collectdConf="$( \
          echo "$_collectdConf"; \
          echo; \
          echo "<Plugin \"mysql\">"; \
          echo "  <Database \"localhost\">"; \
          echo "    Socket \"$COLLECTD_MYSQL_SOCKET\""; \
          echo "$_mysqlConf"; \
          echo "  </Database>"; \
          echo "</Plugin>"; \
        )"
      fi
    fi
  fi

  if [ ! -z "$COLLECTD_REDIS_HOST" ]; then
    _redisIp="$( getent hosts $COLLECTD_REDIS_HOST | awk '{ print $1 }' )"
    _redisPort=${COLLECTD_REDIS_PORT:-6379}
    if [ -z "$_redisIp" ]; then
      echo "COLLECTD_REDIS_HOST ($COLLECTD_REDIS_HOST) host not found." >&2
    else
      _collectdConf="$( \
        echo "$_collectdConf"; \
        echo ""; \
        echo "<Plugin \"redis\">"; \
        echo "  <Node \"$COLLECTD_REDIS_HOST\">"; \
        echo "    Host \"$COLLECTD_REDIS_HOST\""; \
        echo "    Port \"$_redisPort\""; \
      )"

      if [ ! -z "$COLLECTD_REDIS_PASSWORD" ]; then
        _collectdConf="$( \
          echo "$_collectdConf"; \
          echo "    Password \"$COLLECTD_REDIS_PASSWORD\""; \
        )"
      fi

      _collectdConf="$( \
        echo "$_collectdConf"; \
        echo "  </Node>"; \
        echo "</Plugin>"; \
      )"
    fi
  fi

  if [ ! -z "$COLLECTD_WEB_HOST" ]; then
    _webIp="$( getent hosts $COLLECTD_WEB_HOST | awk '{ print $1 }' )"
    _webPort=${COLLECTD_WEB_PORT:-"80"}
    if [ -z "$_webIp" ]; then
      echo "COLLECTD_WEB_HOST ($COLLECTD_WEB_HOST) host not found." >&2
    else
      if [ ! -z "$COLLECTD_NGINX_STATUS_PATH" ]; then
        _collectdConf="$( \
          echo "$_collectdConf"; \
          echo ""; \
          echo "<Plugin \"nginx\">"; \
          echo "  URL \"http://$COLLECTD_WEB_HOST:$_webPort$COLLECTD_NGINX_STATUS_PATH\""; \
          echo "</Plugin>"; \
        )"
      fi

      if [ ! -z "$COLLECTD_PHP_FPM_STATUS_PATH" ]; then
        _collectdConf="$( \
          echo "$_collectdConf"; \
          echo ""; \
          echo "<Plugin curl_json>"; \
          echo "  <URL \"http://$COLLECTD_WEB_HOST:$_webPort$COLLECTD_PHP_FPM_STATUS_PATH?json\">"; \
          echo "    Instance 'main'"; \
          echo "    <Key \"accepted conn\">"; \
          echo "      Type \"phpfpm_requests\""; \
          echo "      Instance \"\""; \
          echo "    </Key>"; \
          echo "    <Key \"slow requests\">"; \
          echo "      Type \"phpfpm_slow_requests\""; \
          echo "      Instance \"\""; \
          echo "    </Key>"; \
          echo "    <Key \"listen queue\">"; \
          echo "      Type \"phpfpm_listen_queue\""; \
          echo "      Instance \"\""; \
          echo "    </Key>"; \
          echo "    <Key \"active processes\">"; \
          echo "      Type \"phpfpm_processes\""; \
          echo "      Instance \"active\""; \
          echo "    </Key>"; \
          echo "    <Key \"total processes\">"; \
          echo "      Type \"phpfpm_processes\""; \
          echo "      Instance \"total\""; \
          echo "    </Key>"; \
          echo "  </URL>"; \
          echo "</Plugin>"; \
        )"
      fi
    fi
  fi

  echo "$_collectdConf" | tee "/etc/collectd/collectd.conf"
fi

echo "Executing $@..."
exec "$@"