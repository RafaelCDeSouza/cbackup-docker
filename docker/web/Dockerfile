FROM php:7.4-apache

ARG CBACKUP_CORE_REPO=https://github.com/cBackup/core.git
ARG CBACKUP_CORE_BRANCH=master

ENV DEBIAN_FRONTEND=noninteractive
ENV CBACKUP_HOME=/opt/cbackup
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_PROCESS_TIMEOUT=1200
ENV COMPOSER_IPRESOLVE=4

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    unzip \
    curl \
    wget \
    vim \
    nano \
    less \
    openssh-client \
    openssh-server \
    snmp \
    libsnmp-dev \
    libicu-dev \
    libzip-dev \
    libgmp-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libonig-dev \
    libssh2-1-dev \
    libssl-dev \
    libmcrypt-dev \
    iputils-ping \
    mariadb-client \
    procps \
    default-jre-headless \
    && docker-php-ext-install \
      bcmath \
      curl \
      gmp \
      intl \
      mbstring \
      mysqli \
      pdo \
      pdo_mysql \
      snmp \
      zip \
    && pecl install ssh2-1.3.1 \
    && docker-php-ext-enable ssh2 \
    && (pecl install mcrypt-1.0.4 && docker-php-ext-enable mcrypt || true) \
    && a2enmod rewrite headers \
    && rm -rf /var/lib/apt/lists/*

# Composer 2.2 LTS: compatível com PHP 7.4 e Packagist atual.
RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && php /tmp/composer-setup.php --version=2.2.25 --install-dir=/usr/local/bin --filename=composer \
    && rm -f /tmp/composer-setup.php

# Clona o core web do cBackup.
RUN git clone --depth=1 --branch "${CBACKUP_CORE_BRANCH}" "${CBACKUP_CORE_REPO}" "${CBACKUP_HOME}"

WORKDIR ${CBACKUP_HOME}

# Pacotes legados que desapareceram do Bitbucket:
#
# - dautkom/php.ipv4
# - dautkom/php.netsnmp
#
# Criamos pacotes locais mínimos para satisfazer o Composer.
# A extensão PHP snmp já está instalada no container.
RUN mkdir -p local-packages/php.ipv4/src \
    && mkdir -p local-packages/php.netsnmp/src \
    && cat > local-packages/php.ipv4/composer.json <<'EOF'
{
  "name": "dautkom/php.ipv4",
  "version": "1.0.2",
  "type": "library",
  "autoload": {
    "classmap": ["src/"]
  }
}
EOF

RUN cat > local-packages/php.ipv4/src/IPv4.php <<'EOF'
<?php

// Placeholder para pacote legado dautkom/php.ipv4.
// A classe real usada pelo cBackup é registrada via local-overrides.
EOF

RUN cat > local-packages/php.netsnmp/composer.json <<'EOF'
{
  "name": "dautkom/php.netsnmp",
  "version": "1.0.1",
  "type": "library",
  "autoload": {
    "classmap": ["src/"]
  }
}
EOF

RUN cat > local-packages/php.netsnmp/src/NetSNMP.php <<'EOF'
<?php

// Placeholder para pacote legado dautkom/php.netsnmp.
// A extensão PHP snmp já está instalada no container.
EOF

# Classe substituta para dautkom\ipv4\IPv4.
RUN mkdir -p local-overrides/dautkom/ipv4 \
    && cat > local-overrides/dautkom/ipv4/IPv4.php <<'EOF'
<?php

namespace dautkom\ipv4;

class IPv4
{
    public function ip2long($ip)
    {
        return ip2long($ip);
    }

    public function long2ip($long)
    {
        return long2ip($long);
    }

    public function validate($ip)
    {
        return filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) !== false;
    }

    public function isValid($ip)
    {
        return $this->validate($ip);
    }

    public function cidrToNetmask($cidr)
    {
        $cidr = (int) $cidr;

        if ($cidr < 0 || $cidr > 32) {
            return false;
        }

        return long2ip((0xffffffff << (32 - $cidr)) & 0xffffffff);
    }

    public function netmaskToCidr($netmask)
    {
        $long = ip2long($netmask);

        if ($long === false) {
            return false;
        }

        return substr_count(decbin($long), '1');
    }

    public function inRange($ip, $network)
    {
        if (strpos($network, '/') === false) {
            return $ip === $network;
        }

        list($subnet, $cidr) = explode('/', $network, 2);

        $ipLong = ip2long($ip);
        $subnetLong = ip2long($subnet);
        $cidr = (int) $cidr;

        if ($ipLong === false || $subnetLong === false || $cidr < 0 || $cidr > 32) {
            return false;
        }

        $mask = (0xffffffff << (32 - $cidr)) & 0xffffffff;

        return (($ipLong & $mask) === ($subnetLong & $mask));
    }
}
EOF

# Corrige composer.json:
#
# 1. Composer 2 não aceita pacote com uppercase:
#      bower-asset/blockUI
#    Corrigimos para:
#      bower-asset/blockui
#
# 2. Adiciona Asset Packagist para pacotes bower-asset.
#
# 3. Libera plugin yiisoft/yii2-composer.
#
# 4. Remove repositórios legados quebrados de dautkom/Bitbucket/GitHub.
#
# 5. Declara os pacotes locais dautkom/php.ipv4 e dautkom/php.netsnmp.
#
# 6. Registra PSR-4 para dautkom\ipv4\IPv4.
RUN sed -i 's#bower-asset/blockUI#bower-asset/blockui#g' composer.json \
    && composer config repositories.asset-packagist composer https://asset-packagist.org \
    && composer config allow-plugins.yiisoft/yii2-composer true \
    && php -r '\
$file="composer.json";\
$json=json_decode(file_get_contents($file), true);\
if (!isset($json["repositories"]) || !is_array($json["repositories"])) {\
    $json["repositories"]=[];\
}\
foreach ($json["repositories"] as $key => $repo) {\
    $encoded=json_encode($repo);\
    if (\
        stripos((string)$key, "dautkom") !== false ||\
        stripos($encoded, "dautkom/php.ipv4") !== false ||\
        stripos($encoded, "dautkom/php.netsnmp") !== false ||\
        stripos($encoded, "PHP.IPv4") !== false ||\
        stripos($encoded, "php.netsnmp") !== false ||\
        stripos($encoded, "bitbucket.org/dautkom") !== false ||\
        stripos($encoded, "github.com/dautkom") !== false\
    ) {\
        unset($json["repositories"][$key]);\
    }\
}\
$json["repositories"]["asset-packagist"] = [\
    "type" => "composer",\
    "url" => "https://asset-packagist.org"\
];\
$json["repositories"]["local-php-ipv4"] = [\
    "type" => "path",\
    "url" => "local-packages/php.ipv4",\
    "options" => ["symlink" => false]\
];\
$json["repositories"]["local-php-netsnmp"] = [\
    "type" => "path",\
    "url" => "local-packages/php.netsnmp",\
    "options" => ["symlink" => false]\
];\
if (!isset($json["autoload"]) || !is_array($json["autoload"])) {\
    $json["autoload"]=[];\
}\
if (!isset($json["autoload"]["psr-4"]) || !is_array($json["autoload"]["psr-4"])) {\
    $json["autoload"]["psr-4"]=[];\
}\
$json["autoload"]["psr-4"]["dautkom\\\\ipv4\\\\"] = "local-overrides/dautkom/ipv4/";\
file_put_contents($file, json_encode($json, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES));\
'

# Remove lock antigo preso em URLs Bitbucket e instala dependências novamente.
RUN rm -f composer.lock \
    && rm -rf vendor \
    && composer clear-cache \
    && composer update \
      --prefer-dist \
      --no-interaction \
      --no-scripts \
      --optimize-autoloader \
      --ignore-platform-reqs \
    && composer dump-autoload -o

COPY docker/web/apache-vhost.conf /etc/apache2/sites-available/000-default.conf
COPY docker/web/php.ini /usr/local/etc/php/conf.d/99-cbackup.ini
COPY docker/web/entrypoint.sh /usr/local/bin/cbackup-web-entrypoint

# Diretórios necessários para Yii2, assets, dados, logs e sessões PHP.
RUN mkdir -p ${CBACKUP_HOME}/runtime \
    && mkdir -p ${CBACKUP_HOME}/web/assets \
    && mkdir -p ${CBACKUP_HOME}/data \
    && mkdir -p ${CBACKUP_HOME}/git \
    && mkdir -p ${CBACKUP_HOME}/bin \
    && mkdir -p /var/log/cbackup \
    && mkdir -p /var/lib/php/sessions \
    && mkdir -p /run/sshd \
    && chmod +x /usr/local/bin/cbackup-web-entrypoint \
    && chown -R www-data:www-data \
      ${CBACKUP_HOME}/runtime \
      ${CBACKUP_HOME}/web/assets \
      ${CBACKUP_HOME}/data \
      ${CBACKUP_HOME}/git \
      /var/log/cbackup \
      /var/lib/php/sessions \
    && chmod -R 775 \
      ${CBACKUP_HOME}/runtime \
      ${CBACKUP_HOME}/web/assets \
      ${CBACKUP_HOME}/data \
      ${CBACKUP_HOME}/git \
      /var/log/cbackup \
    && chmod 1777 /var/lib/php/sessions \
    && chown www-data:www-data ${CBACKUP_HOME}/bin \
    && chmod 775 ${CBACKUP_HOME}/bin \
    && chmod 555 ${CBACKUP_HOME}/yii || true \
    && chmod 444 ${CBACKUP_HOME}/yii.bat || true

ENTRYPOINT ["cbackup-web-entrypoint"]
CMD ["apache2-foreground"]
