#!/usr/bin/env bash
# Remove install.lock e limpa o banco para permitir reinstalação.
set -euo pipefail

cd "$(dirname "$0")/.."

source .env 2>/dev/null || true

DB_HOST="${DB_HOST:-cbackup-db}"
DB_NAME="${MYSQL_DATABASE:-cbackup}"
DB_USER="${MYSQL_USER:-cbackup}"
DB_PASS="${MYSQL_PASSWORD:-cbackup_pass}"
DB_ROOT_PASS="${MYSQL_ROOT_PASSWORD:-root_pass}"

echo "==> Removendo install.lock..."
docker exec cbackup-web rm -f /opt/cbackup/install.lock

echo "==> Limpando banco de dados '${DB_NAME}'..."
docker exec cbackup-db mariadb -uroot -p"${DB_ROOT_PASS}" \
    -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8 COLLATE utf8_general_ci; GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%'; FLUSH PRIVILEGES;"

echo "==> Reiniciando cbackup-web..."
docker compose restart cbackup-web

echo ""
echo "Pronto! Acesse o instalador em:"
echo "  http://localhost:${CBACKUP_HTTP_PORT:-8080}/index.php?r=install"
