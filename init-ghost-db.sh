#!/bin/bash
# set -e

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
        echo "need all 3 arguments: [vault's host] [vault's port] [vault token], got: '$@'" >&2
        return 1
    fi
}

function securingRoot {
    psql -v ON_ERROR_STOP=1 -h localhost --username "$root_user" <<-EOSQL
        ALTER USER $root_user WITH ENCRYPTED PASSWORD '$root_password';
EOSQL
}

function createUser { 

    local u=$(jq -r .username <<< $1)
    local p=$(jq -r .password <<< $1)

    echo "creating user: $u"

    psql -v ON_ERROR_STOP=1 -h localhost --username "$root_user" <<-EOSQL
        CREATE USER $u WITH ENCRYPTED PASSWORD '$p';
EOSQL
}

function createDatabase {

    local db=$(jq -r .name <<< $1)
    
    echo "creating a database: $db"

    psql -v ON_ERROR_STOP=1 -h localhost --username "$root_user" <<-EOSQL
        CREATE DATABASE $db;
EOSQL
}

function provisionDatabase {

    createDatabase $1

    local db=$(jq -r .name <<< $1)

    jq '.users[]' <<< $1 | while read u; do
        echo "setting up a user: $u"

        psql -v ON_ERROR_STOP=1 -h localhost --username "$root_user" <<-EOSQL
            GRANT ALL PRIVILEGES ON DATABASE $db TO $u;
EOSQL
    done
}

creds=$(readCreds $VAULT_HOST $VAULT_PORT $VAULT_TOKEN)
# creds=`cat ./creds`

# echo creds: $creds

root_user=$(jq -r '.root.username' <<< $creds)
root_password=$(jq -r '.root.password' <<< $creds)

## creating users
jq -c '.users[]' <<< $creds | while read u; do
    createUser $u
done

# ## creating and provisioning databases
jq -c '.dbs[]' <<< $creds | while read d; do
   provisionDatabase $d 
done

securingRoot

if [[ -n $PG_HBA ]]; then
    mv $PG_HBA $PGDATA/
    chown -R $root_user:$root_user $PGDATA
fi
