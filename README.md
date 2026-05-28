# cBackup via Docker Compose

Ambiente completo do cBackup usando imagens pré-compiladas publicadas no Docker Hub.

- Web core: [`cBackup/core`](https://github.com/cBackup/core.git) (Apache + PHP 7.4)
- Java daemon: [`cBackup/worker`](https://github.com/cBackup/worker.git) (Java + cBackup worker)
- Banco de dados: MariaDB 10.6

## Serviços

| Serviço | Imagem | Função |
|---|---|---|
| `cbackup-web` | `rafaelcdesouza/cbackup-web` | Apache + PHP 7.4 + cBackup core |
| `cbackup-daemon` | `rafaelcdesouza/cbackup-daemon` | Java daemon/worker |
| `cbackup-db` | `mariadb:10.6` | Banco de dados |

## Primeira instalação

```bash
cp .env.example .env
# Edite as variáveis obrigatórias no .env
docker compose up -d
```

Ou use o script auxiliar:

```bash
./scripts/up.sh
```

Aguarde os containers subirem e acesse o wizard de instalação:

```
http://IP_DO_SERVIDOR:8080
```

### Dados do banco no wizard

```
Host:     cbackup-db
Porta:    3306
Database: cbackup
User:     cbackup
Password: valor de MYSQL_PASSWORD no .env
```

Após concluir o wizard, **copie o `cookieValidationKey`** gerado e adicione ao `.env`:

```ini
CBACKUP_COOKIE_KEY=valor_gerado_pelo_wizard
```

Esse valor é necessário para que as sessões sobrevivam a recreações do container.

## Variáveis de ambiente (.env)

| Variável | Padrão | Descrição |
|---|---|---|
| `MYSQL_DATABASE` | `cbackup` | Nome do banco |
| `MYSQL_USER` | `cbackup` | Usuário do banco |
| `MYSQL_PASSWORD` | — | Senha do usuário do banco |
| `MYSQL_ROOT_PASSWORD` | — | Senha root do MariaDB |
| `CBACKUP_HTTP_PORT` | `8080` | Porta HTTP da interface web |
| `CBACKUP_DAEMON_SSH_PORT` | `8437` | Porta SSH interna do daemon |
| `CBACKUP_SSH_ROOT_PASSWORD` | — | Senha root SSH (usada pelo instalador) |
| `CBACKUP_COOKIE_KEY` | — | Cookie validation key (gerado no wizard) |
| `TZ` | `America/Sao_Paulo` | Timezone |

## Portas

```
8080  → interface web       (configurável via CBACKUP_HTTP_PORT)
8437  → SSH interno daemon  (configurável via CBACKUP_DAEMON_SSH_PORT)
```

## Logs

```bash
docker compose logs -f --tail=200
```

Por serviço:

```bash
docker compose logs -f cbackup-web
docker compose logs -f cbackup-daemon
```

Ou:

```bash
./scripts/logs.sh
```

## Comandos úteis

```bash
# Status dos containers
docker compose ps

# Testar porta do daemon
nc -vz IP_DO_SERVIDOR 8437

# Abrir shell no container web
./scripts/shell-web.sh

# Abrir shell no container daemon
./scripts/shell-daemon.sh
```

## Reinstalar (reset completo)

Remove o lock de instalação e limpa o banco, permitindo passar pelo wizard novamente:

```bash
./scripts/reset-install.sh
```

## Backup dos volumes

Todos os dados persistentes ficam em volumes Docker nomeados:

| Volume | Conteúdo |
|---|---|
| `cbackup_db` | Banco de dados MariaDB |
| `cbackup_config` | Configurações da aplicação (settings.ini, web.php, etc.) |
| `cbackup_web_runtime` | Runtime da aplicação e marcador de instalação |
| `cbackup_data` | Dados coletados dos dispositivos |
| `cbackup_git` | Repositórios Git dos backups |
| `cbackup_logs` | Logs da aplicação |
| `cbackup_bin` | Binários (daemon jar) |
| `cbackup_web_assets` | Assets web gerados |

## Produção

- Publique a web atrás de Nginx Proxy Manager, Traefik ou Cloudflare Tunnel
- Não exponha o MariaDB externamente
- Restrinja a porta `8437` por firewall
- Configure `CBACKUP_COOKIE_KEY` no `.env` para manter sessões após atualizações

## Atualizar para nova versão das imagens

Edite as tags das imagens no `docker-compose.yml` e rode:

```bash
docker compose pull
docker compose up -d
```

## Recompilar as imagens localmente

Descomente a seção `build:` no `docker-compose.yml` (e comente a linha `image:`) e rode:

```bash
./scripts/rebuild.sh
```

## Observações técnicas

1. O `DocumentRoot` do Apache aponta para `/opt/cbackup/web`.
2. O core usa dependências PHP antigas — a imagem usa PHP 7.4 e Composer 2.2.25.
3. O `install.lock` é um symlink para `runtime/.install.lock` dentro do volume `cbackup_web_runtime`, garantindo persistência entre recreações do container.
4. O `settings.ini` fica no volume `cbackup_config` e pode ser regenerado automaticamente via `CBACKUP_COOKIE_KEY` no `.env`.
5. Se uma dependência antiga do Maven ou Composer sumir dos repositórios públicos, o build local pode falhar. Nesse caso, use as imagens pré-compiladas do Docker Hub.
