#!/bin/sh

git submodule update \
	&& docker build -t xfrocks/docker-collectd . \
	&& docker push xfrocks/docker-collectd