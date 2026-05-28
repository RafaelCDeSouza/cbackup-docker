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
    sshpass \
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

RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && php /tmp/composer-setup.php --version=2.2.25 --install-dir=/usr/local/bin --filename=composer \
    && rm -f /tmp/composer-setup.php

RUN git clone --depth=1 --branch "${CBACKUP_CORE_BRANCH}" "${CBACKUP_CORE_REPO}" "${CBACKUP_HOME}"

WORKDIR ${CBACKUP_HOME}

# Usa composer.json/composer.lock funcionais, gerados no container validado.
COPY docker/web/fixed/composer.json ${CBACKUP_HOME}/composer.json
COPY docker/web/fixed/composer.lock ${CBACKUP_HOME}/composer.lock
COPY docker/web/fixed/local-packages ${CBACKUP_HOME}/local-packages
COPY docker/web/fixed/local-overrides ${CBACKUP_HOME}/local-overrides

RUN sed -i 's#bower-asset/blockUI#bower-asset/blockui#g' composer.json composer.lock || true \
    && composer config allow-plugins.yiisoft/yii2-composer true \
    && COMPOSER_IPRESOLVE=4 COMPOSER_PROCESS_TIMEOUT=1200 composer install \
    --prefer-dist \
    --no-interaction \
    --no-scripts \
    --optimize-autoloader \
    --ignore-platform-reqs \
    && composer dump-autoload -o \
    && php -r 'require "/opt/cbackup/vendor/autoload.php"; if (!class_exists("dautkom\\ipv4\\IPv4")) { fwrite(STDERR, "IPv4 class missing\n"); exit(1); } echo "IPv4 class OK\n";'

COPY docker/web/apache-vhost.conf /etc/apache2/sites-available/000-default.conf
COPY docker/web/php.ini /usr/local/etc/php/conf.d/99-cbackup.ini
COPY docker/web/entrypoint.sh /usr/local/bin/cbackup-web-entrypoint
COPY docker/web/fixed/web.php ${CBACKUP_HOME}/config/web.php

RUN mkdir -p ${CBACKUP_HOME}/runtime \
    ${CBACKUP_HOME}/web/assets \
    ${CBACKUP_HOME}/web/install/assets \
    ${CBACKUP_HOME}/data \
    ${CBACKUP_HOME}/git \
    ${CBACKUP_HOME}/bin \
    /var/log/cbackup \
    /var/lib/php/sessions \
    /run/sshd \
    && chmod +x /usr/local/bin/cbackup-web-entrypoint \
    && rm -f ${CBACKUP_HOME}/install.lock ${CBACKUP_HOME}/web/install.lock \
    && chown -R www-data:www-data \
    ${CBACKUP_HOME}/runtime \
    ${CBACKUP_HOME}/web/assets \
    ${CBACKUP_HOME}/web/install/assets \
    ${CBACKUP_HOME}/data \
    ${CBACKUP_HOME}/git \
    /var/log/cbackup \
    /var/lib/php/sessions \
    && chmod -R 775 \
    ${CBACKUP_HOME}/runtime \
    ${CBACKUP_HOME}/web/assets \
    ${CBACKUP_HOME}/web/install/assets \
    ${CBACKUP_HOME}/data \
    ${CBACKUP_HOME}/git \
    /var/log/cbackup \
    && chmod 1777 /var/lib/php/sessions \
    && chown www-data:www-data ${CBACKUP_HOME}/bin \
    && chmod 775 ${CBACKUP_HOME}/bin


ENTRYPOINT ["cbackup-web-entrypoint"]
CMD ["apache2-foreground"]