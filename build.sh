#!/bin/sh

set -e

mkdir -p plugin/rootfs
docker-compose rm -sf do_storage
docker-compose up --no-start do_storage
docker export $(docker-compose ps -q do_storage) | tar -x -C plugin/rootfs
cp config.json plugin/
docker-compose rm -sf do_storage

docker plugin rm -f cjbottaro/do_storage:latest || true
docker plugin create cjbottaro/do_storage:latest plugin
