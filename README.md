
_this repo is `in progress`.. once this is close to be alpha, the docs will follow_

# What is it?

This is a docker image that combines an official [PostreSQL](https://www.postgresql.org/) docker image
with getting its creds from [Vault](https://www.vaultproject.io/).

## Why bother?

Most of the official images, including [Postgres](https://hub.docker.com/_/postgres/), recommend passing credentials to a docker image via
environment variables. This is a _***very insecure way**_ to do business, since all child processes can see these variables in clear text.
Moreover these variables would show up in `docker inspect`, OS logs, and many more places.

Keeping DB, and other, credentials in Vault allows for a lot better security and safe ways of storing and obtaining these credentials whenever they are needed.

`psql-vault` does that and a bit more: it would  _optionally_ provision dbs, users and a custom Postgres' host based authentication.

## Use it

### Configuration

It can be as minimal as:

```json
{"root": {"username": "postgres",
          "password": "CHANGE-ME-root-pass"}}
```

to something a lot more involved:

```json
{"root": {"username": "postgres",
          "password": "CHANGE-ME-root-pass"},
 "users": [{"username": "ghost",
            "password": "CHANGE-ME-TOO-ghost-pass"},
           {"username": "producer",
            "password": "CHANGE-ME-TOO-producer-pass"},
           {"username": "artist",
            "password": "CHANGE-ME-TOO-artist-pass"},
           {"username": "guest",
            "password": "CHANGE-ME-TOO-guest-pass"}],
 "dbs": [{"name": "ghost_blog",
          "users": ["ghost"]},
         {"name": "music_library",
          "users": ["producer", "artist"]}]}
```

> TODO: documentation

### Host base access

Postgres keeps its "gates" in [`pg_hba.conf`](https://www.postgresql.org/docs/9.5/static/auth-pg-hba-conf.html).

When running `psql-vault` image, you can provide your own `pg_hba.conf` setting `PG_HBA` env variable which is a path to a custom `pg_hba.conf`.

> TODO: documentation

# Trying it

In order to try a sample with this image, we would need Vault running.
You can use your own Vault instance / cluster, or just follow the next section.

## Starting Vault

```bash
docker run --name=dev-vault -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' -p 8200:8200 -d vault
```

```bash
docker logs dev-vault
```
will show the vault's logs:

>_export VAULT_ADDR='http://0.0.0.0:8200'_

>_..._

>_Root Token: 75de9b20-16fa-5a1e-2e9a-39c86caef504_


we would need 2 pieces of data from the above, to export a root token and a host address:

```bash
export VAULT_TOKEN=75de9b20-16fa-5a1e-2e9a-39c86caef504
export VAULT_ADDR='http://127.0.0.1:8200'
```

In production this would (already be there or) be done on a _different_ machine (or potentially a Vault cluster) and with more unseal keys, etc..

### One step config

```bash
git clone https://github.com/tolitius/psql-vault
cd sample
```

Open `.env` file, and since Vault is running on the _same host_ in this case, set `VAULT_HOST` to the _host IP_.

> if you are unsure what your host IP is, just ask
```bash
./tools/what-is-my-host-ip.sh
192.168.1.12                    ## this is an example output, your IP most likely will be different
```

Pretending `192.168.1.12` is your host IP, a `VAULT_HOST` would look like:

```properties
VAULT_HOST=192.168.1.12
```

## Store creds in Vault

```bash
./tools/vault/vault-write.sh /secret/postgres creds
```

The reason it is done via file (rather than providing creds in clear) is not to leave creds traces in bash/shell history.

You can check whether the creds were successfully written to Vault:

```bash
./tools/vault/vault-read.sh /secret/postgres
```
```json
{"root": {"username": "postgres",
          "password": "CHANGE-ME-root-pass"},
 "users": [{"username": "ghost",
            "password": "CHANGE-ME-TOO-ghost-pass"},
           {"username": "producer",
            "password": "CHANGE-ME-TOO-producer-pass"},
           {"username": "artist",
            "password": "CHANGE-ME-TOO-artist-pass"},
           {"username": "guest",
            "password": "CHANGE-ME-TOO-guest-pass"}],
 "dbs": [{"name": "ghost_blog",
          "users": ["ghost"]},
         {"name": "music_library",
          "users": ["producer", "artist"]}]}
```

> _NOTE: for these vault scripts to work you would need [jq](https://stedolan.github.io/jq/) (i.e. to parse JSON responses from Vault)._

> _`brew install jq` or `apt-get install jq` or similar_

## Running it

```bash
export ACCESS_TOKEN=$(./tools/vault/wrap-token.sh /secret/postgres); docker-compose up
```
notice we are using Vault to create a temp token (wrapping our "secret") that is passed to docker containers.

as it's starting for the firt time, you'll see how it provisions the config above:
```bash
db  | /docker-entrypoint.sh: running /docker-entrypoint-initdb.d/provision-users-and-dbs.sh
db  | creating user: ghost
db  | creating user: producer
db  | creating user: artist
db  | creating user: guest
db  | creating a database: ghost_blog
db  | setting up a user: "ghost"
db  | creating a database: music_library
db  | setting up a user: "producer"
db  | setting up a user: "artist"
db  | applying a custom host based access (pg_hba)
```

### Looking under the hood

```bash
$ psql -h localhost -U postgres -l                                                                                                   (master ✱ )
                                   List of databases
     Name      |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
---------------+----------+----------+------------+------------+-----------------------
 ghost_blog    | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =Tc/postgres         +
               |          |          |            |            | postgres=CTc/postgres+
               |          |          |            |            | ghost=CTc/postgres
 music_library | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =Tc/postgres         +
               |          |          |            |            | postgres=CTc/postgres+
               |          |          |            |            | producer=CTc/postgres+
               |          |          |            |            | artist=CTc/postgres
 postgres      | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 template0     | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
               |          |          |            |            | postgres=CTc/postgres
 template1     | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
               |          |          |            |            | postgres=CTc/postgres
(5 rows)
```

```bash
postgres=# \du
                                   List of roles
 Role name |                         Attributes                         | Member of
-----------+------------------------------------------------------------+-----------
 artist    |                                                            | {}
 ghost     |                                                            | {}
 guest     |                                                            | {}
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS | {}
 producer  |                                                            | {}
```
