#!/usr/bin/env bash
set -euo pipefail

CBACKUP_HOME="${CBACKUP_HOME:-/opt/cbackup}"

mkdir -p "$CBACKUP_HOME/runtime"
mkdir -p "$CBACKUP_HOME/web/assets"
mkdir -p "$CBACKUP_HOME/web/install/assets"
mkdir -p "$CBACKUP_HOME/data"
mkdir -p "$CBACKUP_HOME/config"
mkdir -p "$CBACKUP_HOME/git"
mkdir -p "$CBACKUP_HOME/bin"
mkdir -p /var/log/cbackup
mkdir -p /var/lib/php/sessions
mkdir -p /run/sshd
mkdir -p /etc/ssh/sshd_config.d

# SSH local usado pelo instalador
echo "root:${CBACKUP_SSH_ROOT_PASSWORD:-cbackup}" | chpasswd || true

cat > /etc/ssh/sshd_config.d/99-cbackup.conf <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
EOF

pkill sshd 2>/dev/null || true
/usr/sbin/sshd || true

chown www-data:www-data "$CBACKUP_HOME" || true
chmod 775 "$CBACKUP_HOME" || true

chown -R www-data:www-data \
  "$CBACKUP_HOME/runtime" \
  "$CBACKUP_HOME/web/assets" \
  "$CBACKUP_HOME/web/install/assets" \
  "$CBACKUP_HOME/data" \
  "$CBACKUP_HOME/config" \
  "$CBACKUP_HOME/git" \
  /var/log/cbackup \
  /var/lib/php/sessions || true

chmod -R 775 \
  "$CBACKUP_HOME/runtime" \
  "$CBACKUP_HOME/web/assets" \
  "$CBACKUP_HOME/web/install/assets" \
  "$CBACKUP_HOME/data" \
  "$CBACKUP_HOME/config" \
  "$CBACKUP_HOME/git" \
  /var/log/cbackup || true

chmod 1777 /var/lib/php/sessions || true

chown www-data:www-data "$CBACKUP_HOME/bin" || true
chmod 775 "$CBACKUP_HOME/bin" || true

if [ -f "$CBACKUP_HOME/bin/cbackup.jar" ]; then
  chown www-data:www-data "$CBACKUP_HOME/bin/cbackup.jar" || true
  chmod 555 "$CBACKUP_HOME/bin/cbackup.jar" || true
fi

if [ -f "$CBACKUP_HOME/yii" ]; then
  chown www-data:www-data "$CBACKUP_HOME/yii" || true
  chmod 555 "$CBACKUP_HOME/yii" || true
fi

if [ -f "$CBACKUP_HOME/yii.bat" ]; then
  chown www-data:www-data "$CBACKUP_HOME/yii.bat" || true
  chmod 444 "$CBACKUP_HOME/yii.bat" || true
fi

echo "Aguardando banco em ${DB_HOST:-cbackup-db}:${DB_PORT:-3306}..."

until mysqladmin ping \
  -h"${DB_HOST:-cbackup-db}" \
  -P"${DB_PORT:-3306}" \
  -uroot \
  -p"${MYSQL_ROOT_PASSWORD:-root_pass}" \
  --silent 2>/dev/null; do
  sleep 2
done

echo "Banco respondeu. Garantindo database e usuário..."

mysql \
  -h"${DB_HOST:-cbackup-db}" \
  -P"${DB_PORT:-3306}" \
  -uroot \
  -p"${MYSQL_ROOT_PASSWORD:-root_pass}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME:-cbackup}\`
  CHARACTER SET utf8
  COLLATE utf8_general_ci;

CREATE USER IF NOT EXISTS '${DB_USER:-cbackup}'@'%'
  IDENTIFIED BY '${DB_PASSWORD:-cbackup_pass}';

ALTER USER '${DB_USER:-cbackup}'@'%'
  IDENTIFIED BY '${DB_PASSWORD:-cbackup_pass}';

GRANT ALL PRIVILEGES ON \`${DB_NAME:-cbackup}\`.* TO '${DB_USER:-cbackup}'@'%';

FLUSH PRIVILEGES;
SQL

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

echo "Database ${DB_NAME:-cbackup} validado."

# Garante que settings.ini existe no volume de config (gerado a partir de env var).
# Isso evita perder o cookieValidationKey ao recriar o container.
if [ ! -f "$CBACKUP_HOME/config/settings.ini" ] && [ -n "${CBACKUP_COOKIE_KEY:-}" ]; then
  cat > "$CBACKUP_HOME/config/settings.ini" <<INI
cookieValidationKey = "${CBACKUP_COOKIE_KEY}"
defaultTimeZone = "${TZ:-UTC}"
serviceType = "system.d"
INI
  chown www-data:www-data "$CBACKUP_HOME/config/settings.ini" || true
  chmod 640 "$CBACKUP_HOME/config/settings.ini" || true
fi

# install.lock aponta para o volume runtime/ para sobreviver a recreações do container.
# O instalador cria/verifica o lock em $CBACKUP_HOME/install.lock; o symlink redireciona
# para o volume nomeado que persiste entre recreações.
ln -sf "$CBACKUP_HOME/runtime/.install.lock" "$CBACKUP_HOME/install.lock" 2>/dev/null || true

# Volumes compartilhados podem vir com UID/GID diferente.
# O instalador exige escrita nos diretórios data e bin.
chmod 777 "$CBACKUP_HOME/data" || true
chmod 777 "$CBACKUP_HOME/bin" || true

if [ -f "$CBACKUP_HOME/bin/cbackup.jar" ]; then
  chmod 555 "$CBACKUP_HOME/bin/cbackup.jar" || true
fi

if [ -f "$CBACKUP_HOME/yii" ]; then
  chmod 555 "$CBACKUP_HOME/yii" || true
fi

if [ -f "$CBACKUP_HOME/yii.bat" ]; then
  chmod 444 "$CBACKUP_HOME/yii.bat" || true
fi

exec "$@"
