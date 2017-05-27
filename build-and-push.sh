#!/bin/sh

DOCKER_HUB_IMAGE='xfrocks/collectd'
DOCKER_HUB_TAG='2017052703'

git submodule update --init --recursive
docker build -t "$DOCKER_HUB_IMAGE" -t "$DOCKER_HUB_IMAGE:$DOCKER_HUB_TAG" .

docker push "$DOCKER_HUB_IMAGE"
docker push "$DOCKER_HUB_IMAGE:$DOCKER_HUB_TAG"
