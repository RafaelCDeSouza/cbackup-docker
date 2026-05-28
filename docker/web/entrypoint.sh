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

mkdir -p "$CBACKUP_HOME/modules/cds/content"
chown -R www-data:www-data "$CBACKUP_HOME/modules/cds/content" || true
chmod -R 775 "$CBACKUP_HOME/modules/cds/content" || true

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

# Sync Docker env vars into cBackup's config table on every startup.
# The web installer prompts the user for daemon settings, but in Docker those
# values must always match the env vars — this block enforces that without
# requiring manual form-filling during installation.
_db_exec() {
  mysql \
    -h"${DB_HOST:-cbackup-db}" \
    -P"${DB_PORT:-3306}" \
    -uroot \
    -p"${MYSQL_ROOT_PASSWORD:-root_pass}" \
    "${DB_NAME:-cbackup}" \
    -e "$1" 2>/dev/null
}

if _db_exec "SHOW TABLES LIKE 'config';" | grep -q config; then
  _db_exec "UPDATE config SET value = '${JAVA_HOST:-cbackup-daemon}'     WHERE \`key\` = 'javaHost';"
  _db_exec "UPDATE config SET value = '${JAVA_SCHEDULER_USER:-cbadmin}'  WHERE \`key\` = 'javaSchedulerUsername';"
  _db_exec "UPDATE config SET value = '${JAVA_SCHEDULER_PASS:-cbackup}'  WHERE \`key\` = 'javaSchedulerPassword';"
  _db_exec "UPDATE config SET value = '${CBACKUP_SSH_ROOT_PASSWORD:-cbackup}' WHERE \`key\` = 'javaServerPassword';"
  if [ -n "${CBACKUP_TOKEN:-}" ]; then
    _db_exec "UPDATE user SET access_token = '${CBACKUP_TOKEN}' WHERE userid = 'JAVACORE';"
  fi
  rm -rf "${CBACKUP_HOME}/runtime/cache/" 2>/dev/null || true
  echo "Configurações do daemon sincronizadas com variáveis de ambiente."
fi

# Write Apache vhost — ensures the root-path rewrite (/?r=...) for the Java
# daemon API calls survives container recreations and image rebuilds.
cat > /etc/apache2/sites-enabled/000-default.conf <<'VHOSTEOF'
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /opt/cbackup/web

    RewriteEngine On

    RewriteCond %{THE_REQUEST} "\.\."
    RewriteRule ^ - [F,L]

    RedirectMatch 403 "(?i).*(README\.md|yii\.bat|schema\.sql|cbackup\.jar)$"
    RedirectMatch 403 "(?i).*(composer\.json|composer\.lock|\.env|\.git|vendor|runtime|config|bin).*"

    <Directory />
        Require all denied
    </Directory>

    <Directory /opt/cbackup>
        Options -Indexes
        AllowOverride None
        Require all denied
    </Directory>

    <Directory /opt/cbackup/web>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted

        RewriteEngine On

        RewriteCond %{THE_REQUEST} "\.\." [OR]
        RewriteCond %{REQUEST_URI} "\.\."
        RewriteRule ^ - [F,L]

        # Daemon API calls use /?r=route (root path without index.php).
        # Rewrite to index.php so Yii routes them through the v1 module.
        RewriteCond %{REQUEST_URI} ^/?$
        RewriteRule ^ index.php [L,QSA,E=API_ROOT:1]

        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . index.php [L]
    </Directory>

    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>

    ErrorLog ${APACHE_LOG_DIR}/cbackup-error.log
    CustomLog ${APACHE_LOG_DIR}/cbackup-access.log combined
</VirtualHost>
VHOSTEOF

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
# find garante que subdiretórios criados pelo daemon (UID 1000) fiquem
# acessíveis à web (www-data/33) mesmo após recreações de container.
chmod 777 "$CBACKUP_HOME/data" || true
find "$CBACKUP_HOME/data" -type d -exec chmod 777 {} + 2>/dev/null || true
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
