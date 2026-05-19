#!/usr/bin/env bash
set -euo pipefail

CBACKUP_HOME="${CBACKUP_HOME:-/opt/cbackup}"

mkdir -p "$CBACKUP_HOME/data" "$CBACKUP_HOME/git" "$CBACKUP_HOME/bin" /var/log/cbackup

if [ -f /opt/cbackup-worker/cbackup.jar ]; then
  cp -f /opt/cbackup-worker/cbackup.jar "$CBACKUP_HOME/bin/cbackup.jar"
  chown cbackup:cbackup "$CBACKUP_HOME/bin/cbackup.jar" || true
  chmod 555 "$CBACKUP_HOME/bin/cbackup.jar" || true
fi

chown -R cbackup:cbackup "$CBACKUP_HOME" /var/log/cbackup /opt/cbackup-worker || true

until nc -z "${DB_HOST:-cbackup-db}" "${DB_PORT:-3306}"; do
  echo "Aguardando banco em ${DB_HOST:-cbackup-db}:${DB_PORT:-3306}..."
  sleep 2
done

exec "$@"
