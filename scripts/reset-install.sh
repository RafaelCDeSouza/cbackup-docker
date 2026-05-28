#!/usr/bin/env bash
# Remove o marcador de instalação e limpa o banco para permitir reinstalação.
set -euo pipefail

cd "$(dirname "$0")/.."

source .env 2>/dev/null || true

DB_NAME="${MYSQL_DATABASE:-cbackup}"
DB_USER="${MYSQL_USER:-cbackup}"
DB_ROOT_PASS="${MYSQL_ROOT_PASSWORD:-root_pass}"

echo "==> Removendo marcador de instalação..."
# install.lock é um symlink para runtime/.install.lock; removemos o alvo para resetar.
docker exec cbackup-web rm -f /opt/cbackup/runtime/.install.lock

echo "==> Limpando banco de dados '${DB_NAME}'..."
docker exec cbackup-db mariadb -uroot -p"${DB_ROOT_PASS}" \
    -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;
        CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8 COLLATE utf8_general_ci;
        GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
        FLUSH PRIVILEGES;"

echo "==> Reiniciando cbackup-web..."
docker compose restart cbackup-web

echo ""
echo "Pronto! Acesse o wizard em:"
echo "  http://IP_DO_SERVIDOR:${CBACKUP_HTTP_PORT:-8080}"
