FROM alpine:3.4

RUN apk --no-cache --update --repository http://dl-cdn.alpinelinux.org/alpine/edge/main --repository http://dl-cdn.alpinelinux.org/alpine/edge/community --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing add \
    curl \
    openssl \
    ca-certificates \
    php7 \
    php7-fpm \
    php7-curl \
    php7-gd \
    php7-phar \
    php7-pcntl \
    php7-json \
    php7-opcache \
    php7-pdo_mysql \
    php7-mysqlnd \
    php7-mbstring \
    php7-session \
    php7-mcrypt \
    php7-zip \
    php7-sockets \
    php7-openssl \
    php7-iconv \
    php7-mysqli \
    php7-mongodb \
    php7-bcmath \
    php7-session

RUN ln -s /usr/bin/php7 /usr/bin/php

ENV COMPOSER_VERSION 1.11.1
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

ADD thawte_Premium_Server_CA.pem /etc/ssl/certs/thawte_Premium_Server_CA.pem

RUN mkdir /tmp/newrelic \
    && cd /tmp/newrelic \
    && wget "http://download.newrelic.com/php_agent/release/$(curl http://download.newrelic.com/php_agent/release/ | grep -ohE 'newrelic-php5-.*?-linux-musl.tar.gz' | cut -f1 -d\")" -O php-agent.tar.gz \
    && gzip -dc php-agent.tar.gz | tar xf - \
    && mkdir -p /opt/newrelic \
    && cp -a "$(ls | grep 'newrelic')/." /opt/newrelic/ \
    && rm -rf /tmp/newrelic

# PHP
ADD laravel.ini /usr/local/etc/php/conf.d
ADD start.sh /

RUN chmod +x /start.sh

# PHP-FPM
ADD logging.conf www.conf /etc/php7/php-fpm.d/

CMD "/start.sh"