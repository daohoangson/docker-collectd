FROM alpine:3.5

RUN apk add --no-cache --update \
		collectd \
		collectd-curl \
		collectd-mysql \
		collectd-network \
		collectd-nginx \
		collectd-python \
		collectd-redis \
		py2-pip \
	&& (rm "/tmp/"* 2>/dev/null || true) \
	&& (rm -rf /var/cache/apk/* 2>/dev/null || true)

RUN pip install --no-cache-dir --upgrade pip \
	&& pip install --no-cache-dir \
		py-dateutil \
		docker-py>=1.0.0

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY plugins/collectd-haproxy/haproxy.py /plugins/collectd-haproxy/haproxy.py
COPY plugins/docker-collectd-plugin/dockerplugin.py /plugins/docker-collectd-plugin/dockerplugin.py
COPY types.db /usr/share/collectd/types.db

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["collectd", "-f"]