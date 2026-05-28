#!/usr/bin/env bash
set -euo pipefail

CBACKUP_HOME="${CBACKUP_HOME:-/opt/cbackup}"

mkdir -p "$CBACKUP_HOME/data" "$CBACKUP_HOME/git" "$CBACKUP_HOME/bin" /var/log/cbackup /run/sshd

# Configura SSH para acesso root (usado pelo web para verificar/gerenciar o serviço)
echo "root:${CBACKUP_SSH_ROOT_PASSWORD:-cbackup}" | chpasswd

mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-cbackup.conf <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
# phpseclib 2.x (used by cBackup web) requires ssh-rsa for host key negotiation.
# OpenSSH 8.8+ dropped ssh-rsa from defaults; re-enable it explicitly.
HostKeyAlgorithms +ssh-rsa
PubkeyAcceptedAlgorithms +ssh-rsa
EOF

# Gera chaves do host se necessário e inicia sshd
ssh-keygen -A 2>/dev/null || true
/usr/sbin/sshd

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

chmod 777 "$CBACKUP_HOME/data" || true
chmod 777 "$CBACKUP_HOME/git" || true
chmod 777 "$CBACKUP_HOME/bin" || true

if [ -f "$CBACKUP_HOME/bin/cbackup.jar" ]; then
  chmod 555 "$CBACKUP_HOME/bin/cbackup.jar" || true
fi

exec "$@"
