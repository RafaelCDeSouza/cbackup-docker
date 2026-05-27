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

# Diretórios exigidos pelo instalador
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

# bin precisa ser gravável/executável para o instalador
chown www-data:www-data "$CBACKUP_HOME/bin" || true
chmod 775 "$CBACKUP_HOME/bin" || true

# Mas os arquivos sensíveis não podem ficar graváveis
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

echo "Database ${DB_NAME:-cbackup} validado."

# Se install.lock não existe mas o DB já está instalado (tem tabelas), recriar o lock.
# Isso evita que ao recriar o container a aplicação volte para a tela de install.
if [ ! -f "$CBACKUP_HOME/install.lock" ]; then
  TABLE_COUNT=$(mysql \
    -h"${DB_HOST:-cbackup-db}" \
    -P"${DB_PORT:-3306}" \
    -u"${DB_USER:-cbackup}" \
    -p"${DB_PASSWORD:-cbackup_pass}" \
    "${DB_NAME:-cbackup}" \
    -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME:-cbackup}';" \
    --skip-column-names 2>/dev/null || echo "0")
  if [ "${TABLE_COUNT:-0}" -gt 5 ] 2>/dev/null; then
    echo "DB já instalado ($TABLE_COUNT tabelas). Recriando install.lock..."
    touch "$CBACKUP_HOME/install.lock"
    chown www-data:www-data "$CBACKUP_HOME/install.lock" || true
    chmod 444 "$CBACKUP_HOME/install.lock" || true
  fi
fi

# Volumes compartilhados podem vir com UID/GID diferente.
# O instalador exige escrita nos diretórios data e bin.
chmod 777 "$CBACKUP_HOME/data" || true
chmod 777 "$CBACKUP_HOME/bin" || true

# Arquivos sensíveis não podem ficar graváveis.
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