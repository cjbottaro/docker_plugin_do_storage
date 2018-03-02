# Docker Volume Plugin for DigitalOcean Block Storage

This plugin associates a container with a DigitalOcean volume. In swarm mode,
the volume will "follow" the container around to whatever worker it gets
scheduled on.

## Installation

```
docker plugin install cjbottaro/do_storage:latest ACCESS_TOKEN=<your_DO_token>
```

Where `ACCESS_TOKEN` is your DigitalOcean personal access token.

The plugin needs to be installed on each machine where you plan to run
containers that use it, _even in swarm mode_.

## Example

[Create and format](https://www.digitalocean.com/community/tutorials/how-to-use-block-storage-on-digitalocean#creating-and-attaching-volumes) a DigitalOcean volume called `pgdata`.

Given the following `docker-compose.yml` file:
```yaml
version: "3.4"

services:
  postgres:
    image: postgres:alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      PGDATA: /var/lib/postgresql/data/data # Workaround for quirk in image.

volumes:
  pgdata:
    name: pgdata
    driver: cjbottaro/do_storage:latest
```

Create a container, then create a Postgres database, then stop the container.
```sh
node1$ docker-compose up -d
node1$ docker exec $(docker-compose ps -q) createdb foobar
node1$ docker-compose stop
```

Now on a different machine, start a container using the same `docker-compose.yml`.
We can verify that the DigitalOcean volume followed us to this machine by listing
the databases.
```sh
node2$ docker-compose up -d
node2$ docker exec $(docker-compose ps -q) psql -U postgres -l
                                List of databases
Name      |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
-----------+----------+----------+------------+------------+-----------------------
foobar    | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
postgres  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
template0 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
          |          |          |            |            | postgres=CTc/postgres
template1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
          |          |          |            |            | postgres=CTc/postgres
(4 rows)
```

## Caveats

A DigitalOcean volume can only be attached to one node at a time. If you start
a container using a volume that is already in use by a container on another node,
the plugin will detach the volume _from the running container_ and attach it to the
new container. This will probably crash your process.

To illustrate, consider our example above...

```sh
node1$ docker-compose up -d

node2$ docker-compose up -d
node2$ docker exec $(docker-compose ps -q) psql -U postgres -l
                                List of databases
Name      |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
-----------+----------+----------+------------+------------+-----------------------
foobar    | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
postgres  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
template0 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
          |          |          |            |            | postgres=CTc/postgres
template1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
          |          |          |            |            | postgres=CTc/postgres
(4 rows)

node1$ docker exec $(docker-compose ps -q) psql -U postgres -l
psql: FATAL:  could not open relation mapping file "global/pg_filenode.map": No such file or directory
```

We start a container on `node1`, but then we start a container on `node2` and the
volume is detached from `node1` and attached to `node2`. Now when we ask the first
container to list the databases, it give us a fatal error.

## Building

```
docker-compose build do_storage
docker-compose run --rm do_storage_builder
docker plugin push cjbottaro/do_storage:latest
```
