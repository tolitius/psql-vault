#!/bin/bash
set -e

# if [ "$#" -ne 3 ]; then
#     echo "usage: $0 [vault's host] [vault's port] [vault token]"
#     exit 1
# fi
# 
# VAULT_HOST=$1
# VAULT_PORT=$2
# VAULT_TOKEN=$3

# ^^^ these 3 variables would need to be set as env vars rather than args for this script
#     since this script is most likely to be called by postgres container with no args

: ${VAULT_HOST?"env variable VAULT_HOST needs to be set"}
: ${VAULT_PORT?"env variable VAULT_PORT needs to be set"}
: ${VAULT_TOKEN?"env variable VAULT_TOKEN needs to be set"}

# echo ">>> $VAULT_HOST:$VAULT_PORT with token: $VAULT_TOKEN"

##  for this function to work: "curl" and "jq" should be installed
function readCreds {
    if [ $# -eq 3 ]; then
        local vault=$1
        local port=$2
        local token=$3
        local creds=$(curl -s -H "X-Vault-Token: $token" -X GET $vault:$port/v1/cubbyhole/response)
        local errors=$(echo $creds | jq .errors)
        
        if [[ $errors = "null" ]]; then
            echo $creds | jq -j .data.response | jq .data
        else
            echo could not get creds from vault due to: $errors >&2
            return 1
        fi

    else
        echo "need all 3 arguments: [vault's host] [vault's port] [vault token], got: '$@'"
    fi
}

creds=$(readCreds $VAULT_HOST $VAULT_PORT $VAULT_TOKEN)

# echo creds: $creds

ROOT_USER=$(echo $creds | jq -r '.["root-user"]')
ROOT_PASSWORD=$(echo $creds | jq -r '.["root-pass"]')

GHOST_USER=$(echo $creds | jq -r '.["ghost-user"]')
GHOST_PASSWORD=$(echo $creds | jq -r '.["ghost-pass"]')

GHOST_DB_NAME=ghost

# echo "root: $ROOT_USER, $ROOT_PASSWORD"
# echo "ghost: $GHOST_USER, $GHOST_PASSWORD"

mv /pg_hba.conf $PGDATA/
chown -R $ROOT_USER:$ROOT_USER $PGDATA

psql -v ON_ERROR_STOP=1 --username "$ROOT_USER" <<-EOSQL
    ALTER USER $ROOT_USER WITH ENCRYPTED PASSWORD '$ROOT_PASSWORD';
    CREATE USER $GHOST_USER WITH ENCRYPTED PASSWORD '$GHOST_PASSWORD';
    CREATE DATABASE $GHOST_DB_NAME;
    GRANT ALL PRIVILEGES ON DATABASE $GHOST_DB_NAME TO $GHOST_USER;
EOSQL
