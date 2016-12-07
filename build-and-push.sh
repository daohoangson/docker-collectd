#!/bin/sh

git submodule update --init --recursive \
	&& docker build -t xfrocks/docker-collectd . \
	&& docker push xfrocks/docker-collectd