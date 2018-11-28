#!/bin/sh

set -e

# https://pkgs.alpinelinux.org/packages?name=collectd&branch=v3.8
LATEST_VERSION='5.8.0-r1'
DOCKER_HUB_IMAGE='xfrocks/collectd'
DOCKER_HUB_IMAGE_WITH_TAG="${DOCKER_HUB_IMAGE}:5.8.0b"

git submodule update --init --recursive
docker build --build-arg COLLECTD_VERSION="${LATEST_VERSION}" \
  -t "$DOCKER_HUB_IMAGE" \
  -t "$DOCKER_HUB_IMAGE_WITH_TAG" \
  .

while true
do
  read -p "Push ${DOCKER_HUB_IMAGE} and ${DOCKER_HUB_IMAGE_WITH_TAG}? [yN]" yn
  case $yn in
    [Yy]* ) break;;
    * )
      exit 0;;
  esac
done
docker push "$DOCKER_HUB_IMAGE:latest"
docker push "$DOCKER_HUB_IMAGE_WITH_TAG"
