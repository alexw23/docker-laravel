FROM php:7.0-alpine

ADD thawte_Premium_Server_CA.pem /etc/ssl/certs/thawte_Premium_Server_CA.pem

RUN apk --no-cache --update --repository http://dl-3.alpinelinux.org/alpine/edge/community/ add \
    php7-gd \
    php7-sockets \
    php7-zlib \
    php7-intl \
    php7-opcache \
    ca-certificates \
    libpng \
    libmcrypt-dev \
    libjpeg-turbo \
    imagemagick \
    curl \
    bash \
    sed \
    icu

RUN apk --no-cache --update --repository http://dl-3.alpinelinux.org/alpine/edge/community/ add --virtual build-dependencies \
    icu-dev \
    imagemagick-dev \
    libpng-dev \
    libxml2-dev \
    libjpeg-turbo-dev \
    autoconf \
    build-base \
    libtool \
    openssl \
    openssl-dev \
&& pecl install imagick \
&& pecl install mongodb \
&& docker-php-ext-enable imagick \
&& docker-php-ext-enable mongodb \
&& pecl clear-cache \
&& docker-php-ext-configure intl \
&& docker-php-ext-configure gd \
   --with-png-dir=/usr/include/ \
   --with-jpeg-dir=/usr/include/ \
&& docker-php-ext-install \
    pdo_mysql \
    sockets \
    gd \
    intl \
    opcache \
    soap \
    iconv \
    mcrypt \
    bcmath \
    mbstring \
    zip \
    tokenizer \
    pcntl \
&& apk del build-dependencies

# Install Composer
ENV COMPOSER_VERSION 1.11.1
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

ENV PHP_API_VERSION 20151012
ENV NEWRELIC_VERSION 6.6.1.172

RUN curl -#SL https://download.newrelic.com/php_agent/archive/$NEWRELIC_VERSION/newrelic-php5-$NEWRELIC_VERSION-linux-musl.tar.gz | tar xzf - \
&& mv ./newrelic-php5-$NEWRELIC_VERSION-linux-musl/agent/x64/newrelic-$PHP_API_VERSION.so /usr/local/lib/php/extensions/no-debug-non-zts-$PHP_API_VERSION/newrelic.so \
&& mv ./newrelic-php5-$NEWRELIC_VERSION-linux-musl/daemon/newrelic-daemon.x64 /usr/bin/newrelic-daemon \
&& chmod 775 /usr/bin/newrelic-daemon \
&& mkdir /var/log/newrelic \
&& rm -rf ./newrelic-php5-$NEWRELIC_VERSION-linux-musl*

# PHP
ADD laravel.ini /usr/local/etc/php/conf.d