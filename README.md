# cBackup via GitHub + Docker Compose

Este projeto não usa mais `http://cbackup.me/latest`.

Ele monta o ambiente a partir dos repositórios públicos:

- Web core: `https://github.com/cBackup/core.git`
- Java daemon/worker: `https://github.com/cBackup/worker.git`

## Serviços

- `cbackup-web`: Apache + PHP 7.4 + cBackup core
- `cbackup-daemon`: Java 8 + cBackup worker compilado via Maven
- `cbackup-db`: MariaDB 10.6

## Subir

```bash
cp .env.example .env
vim .env

docker compose up -d --build
```

Ou:

```bash
./scripts/up.sh
```

## Acesso

```text
http://IP_DO_SERVIDOR:8080
```

## Dados do banco no wizard

```text
Host: cbackup-db
Porta: 3306
Database: cbackup
User: cbackup
Password: valor de MYSQL_PASSWORD no .env
```

## Portas

```text
8080  -> interface web
8437  -> shell SSH interno do daemon cBackup
```

## Logs

```bash
docker compose logs -f --tail=200
```

Ou:

```bash
./scripts/logs.sh
```

## Testes rápidos

Ver containers:

```bash
docker compose ps
```

Ver logs do web:

```bash
docker compose logs -f cbackup-web
```

Ver logs do daemon:

```bash
docker compose logs -f cbackup-daemon
```

Testar porta do daemon:

```bash
nc -vz 127.0.0.1 8437
```

## Observações técnicas

1. O repositório `core` contém somente a interface web.
2. O repositório `worker` contém somente o daemon Java.
3. O `DocumentRoot` do Apache aponta para `/opt/cbackup/web`.
4. O daemon é compilado no build da imagem com Maven e Java 8.
5. O core usa dependências PHP antigas, por isso a imagem usa PHP 7.4 e Composer 1.10.
6. Se alguma dependência antiga do Maven ou Composer sumir dos repositórios públicos, o build pode falhar. Nesse caso, o caminho mais seguro é criar um mirror interno dos artefatos ou fixar uma imagem já construída.

## Produção

Recomendações:

- Publique a web atrás de Nginx Proxy Manager, Traefik ou Cloudflare Tunnel.
- Não exponha o MariaDB.
- Restrinja a porta `8437` por firewall.
- Faça backup dos volumes Docker:
  - `cbackup_db`
  - `cbackup_data`
  - `cbackup_git`
  - `cbackup_logs`

## Atualizar código do GitHub

```bash
./scripts/rebuild.sh
```

Isso força novo clone/build dos repositórios definidos no `.env`.
