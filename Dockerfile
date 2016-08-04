FROM postgres:latest
MAINTAINER Anatoly "@tolitius"

ENV VAULT_PORT 8200

## these (including a VAULT_PORT above, if different) will be passed as -e on "docker run"
# VAULT_HOST
# VAULT_TOKEN

COPY pg_hba.conf /
COPY init-ghost-db.sh /docker-entrypoint-initdb.d/init-ghost-db.sh

RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install curl wget

# installing latest jq, so we can "jq -j"
RUN cd /opt \ 
      && mkdir jq \
      && wget -O ./jq/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
      && chmod +x ./jq/jq \
      && ln -s /opt/jq/jq /usr/local/bin
