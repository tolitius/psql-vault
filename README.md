having vault installed...
```bash
docker build -t tolitius/psql-vault .; \
docker rm -f db; \
docker run -e VAULT_TOKEN=$(vault read -wrap-ttl=600s -field=wrapping_token secret/postgres | cat) \
           -e VAULT_HOST=[ip address] \
           --name db \
           -p 5432:5432 \
           tolitius/psql-vault
```
this repo is `in progress`.. once this is close to be alpha, the docs will follow
