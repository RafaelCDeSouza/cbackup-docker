#!/usr/bin/env bash
set -euo pipefail

JAR_PATH="/opt/cbackup-worker/cbackup.jar"

if [ ! -f "$JAR_PATH" ]; then
  echo "ERRO: $JAR_PATH não encontrado."
  exit 1
fi

echo "Iniciando cBackup worker: $JAR_PATH"

ARGS=(
  "-Duser.timezone=${TZ:-America/Sao_Paulo}"
  "-jar" "$JAR_PATH"
  "--spring.datasource.url=jdbc:mysql://${DB_HOST:-cbackup-db}:${DB_PORT:-3306}/${DB_NAME:-cbackup}?useUnicode=true&characterEncoding=utf8&useSSL=false"
  "--spring.datasource.username=${DB_USER:-cbackup}"
  "--spring.datasource.password=${DB_PASSWORD:-cbackup_pass}"
  "--cbackup.scheme=${CBACKUP_SCHEME:-http}"
  "--cbackup.site=${CBACKUP_SITE:-cbackup-web}"
)

if [ -n "${CBACKUP_TOKEN:-}" ]; then
  ARGS+=("--cbackup.token=${CBACKUP_TOKEN}")
fi

cd /opt/cbackup
exec runuser -u cbackup -- env PATH="$PATH" java "${ARGS[@]}"
