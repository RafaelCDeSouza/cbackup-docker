#!/usr/bin/env bash
# Sincroniza as variáveis de ambiente do .env com as configurações do cBackup no banco.
# Execute UMA VEZ após o instalador web ser concluído em cada nova implantação.
#
# Uso: ./scripts/post-install.sh
#
# O instalador salva os valores que o usuário digitou no formulário, que podem não
# coincidir com os env vars do Docker. Este script corrige o desalinhamento.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

DB_NAME="${MYSQL_DATABASE:-cbackup}"
ROOT_PASS="${MYSQL_ROOT_PASSWORD:-root_pass}"

JAVA_HOST="${JAVA_HOST:-cbackup-daemon}"
JAVA_SCHEDULER_USER="${JAVA_SCHEDULER_USER:-cbadmin}"
JAVA_SCHEDULER_PASS="${JAVA_SCHEDULER_PASS:-cbackup}"
JAVA_SERVER_PASS="${CBACKUP_SSH_ROOT_PASSWORD:-cbackup}"
CBACKUP_TOKEN="${CBACKUP_TOKEN:-}"

run_sql() {
  docker exec cbackup-db mysql -uroot -p"${ROOT_PASS}" "${DB_NAME}" -e "$1" 2>/dev/null
}

echo "Verificando se a instalação foi concluída..."
if ! run_sql "SHOW TABLES LIKE 'config';" | grep -q config; then
  echo "ERRO: tabela 'config' não encontrada. Execute o instalador web primeiro."
  exit 1
fi

echo "Sincronizando configurações do daemon Java com variáveis de ambiente..."

run_sql "UPDATE config SET value = '${JAVA_HOST}' WHERE \`key\` = 'javaHost';"
run_sql "UPDATE config SET value = '${JAVA_SCHEDULER_USER}' WHERE \`key\` = 'javaSchedulerUsername';"
run_sql "UPDATE config SET value = '${JAVA_SCHEDULER_PASS}' WHERE \`key\` = 'javaSchedulerPassword';"
run_sql "UPDATE config SET value = '${JAVA_SERVER_PASS}' WHERE \`key\` = 'javaServerPassword';"

if [ -n "${CBACKUP_TOKEN}" ]; then
  run_sql "UPDATE user SET access_token = '${CBACKUP_TOKEN}' WHERE userid = 'JAVACORE';"
  echo "Token JAVACORE atualizado."
fi

echo "Limpando cache do Yii..."
docker exec cbackup-web rm -rf /opt/cbackup/runtime/cache/ 2>/dev/null || true

echo ""
echo "=== Verificação ==="
run_sql "SELECT \`key\`, value FROM config WHERE \`key\` IN ('javaHost','javaSchedulerUsername','javaSchedulerPassword','javaServerPassword');"
[ -n "${CBACKUP_TOKEN}" ] && run_sql "SELECT userid, access_token FROM user WHERE userid = 'JAVACORE';"
echo ""
echo "Concluído. Recarregue o Daemon Status no browser."
