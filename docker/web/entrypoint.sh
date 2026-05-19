#!/usr/bin/env bash
set -euo pipefail

CBACKUP_HOME="${CBACKUP_HOME:-/opt/cbackup}"

mkdir -p "$CBACKUP_HOME/runtime"
mkdir -p "$CBACKUP_HOME/web/assets"
mkdir -p "$CBACKUP_HOME/data"
mkdir -p "$CBACKUP_HOME/git"
mkdir -p "$CBACKUP_HOME/bin"
mkdir -p /var/log/cbackup
mkdir -p /var/lib/php/sessions
mkdir -p /run/sshd

cat > "$CBACKUP_HOME/config/db.php" <<PHP
<?php

return [
    'class' => 'yii\db\Connection',
    'dsn' => 'mysql:host=${DB_HOST:-cbackup-db};port=${DB_PORT:-3306};dbname=${DB_NAME:-cbackup}',
    'username' => '${DB_USER:-cbackup}',
    'password' => '${DB_PASSWORD:-cbackup_pass}',
    'charset' => 'utf8',
    'enableSchemaCache' => false,
];
PHP

echo "root:${CBACKUP_SSH_ROOT_PASSWORD:-cbackup}" | chpasswd || true

sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || true
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true

/usr/sbin/sshd || true

# Diretórios graváveis pelo Apache/Yii
chown -R www-data:www-data \
  "$CBACKUP_HOME/runtime" \
  "$CBACKUP_HOME/web/assets" \
  "$CBACKUP_HOME/data" \
  "$CBACKUP_HOME/git" \
  /var/log/cbackup \
  /var/lib/php/sessions || true

chmod -R 775 \
  "$CBACKUP_HOME/runtime" \
  "$CBACKUP_HOME/web/assets" \
  "$CBACKUP_HOME/data" \
  "$CBACKUP_HOME/git" \
  /var/log/cbackup || true

chmod 1777 /var/lib/php/sessions || true

# O diretório bin precisa ser gravável/executável
chown www-data:www-data "$CBACKUP_HOME/bin" || true
chmod 775 "$CBACKUP_HOME/bin" || true

chown -R www-data:www-data "$CBACKUP_HOME/data" || true
chmod 775 "$CBACKUP_HOME/data" || true

# Mas os arquivos dentro dele NÃO podem ficar graváveis
if [ -f "$CBACKUP_HOME/bin/cbackup.jar" ]; then
  chown www-data:www-data "$CBACKUP_HOME/bin/cbackup.jar" || true
  chmod 555 "$CBACKUP_HOME/bin/cbackup.jar" || true
fi

# yii precisa ser executável, mas não gravável
if [ -f "$CBACKUP_HOME/yii" ]; then
  chown www-data:www-data "$CBACKUP_HOME/yii" || true
  chmod 555 "$CBACKUP_HOME/yii" || true
fi

# yii.bat não deve ser gravável nem executável
if [ -f "$CBACKUP_HOME/yii.bat" ]; then
  chown www-data:www-data "$CBACKUP_HOME/yii.bat" || true
  chmod 444 "$CBACKUP_HOME/yii.bat" || true
fi

exec "$@"
