having vault installed...
```bash
docker build -t ghost-psql .; docker rm -f db; docker run -e VAULT_TOKEN=$(vault read -wrap-ttl=600s -field=wrapping_token secret/postgres | cat) -e VAULT_HOST=[your ip] --name db -p 5432:5432 ghost-psql
```
this repo is `in progress`.. once this is close to be alpha, the docs will follow
