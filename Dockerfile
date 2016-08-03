FROM postgres:latest

ENV VAULT_HOST 127.0.0.1
ENV VAULT_PORT 8200
# ENV VAULT_TOKEN        # will be passed as -e on "docker run"

COPY pg_hba.conf /
COPY init-ghost-db.sh /docker-entrypoint-initdb.d/init-ghost-db.sh

RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install curl wget

# installing latest jq
RUN cd /opt \ 
      && mkdir jq \
      && wget -O ./jq/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
      && chmod +x ./jq/jq \
      && ln -s /opt/jq/jq /usr/local/bin
