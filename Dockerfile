# Using https://github.com/gliderlabs/docker-alpine,
# plus  https://github.com/just-containers/s6-overlay for a s6 Docker overlay.
FROM docker.io/alpine:3 AS builder
# Initially was based on work of Christian Lück <christian@lueck.tv>.
LABEL description="A complete, self-hosted Tiny Tiny RSS (TTRSS) environment." \
      maintainer="Andreas Löffler <andy@x86dev.com>"

# Note! When changing this version, also make sure to adapt the scripts which use / lookup the according binaries.
ARG PHP_VER=84

RUN set -xe && \
    apk update && apk upgrade && \
    apk add --no-cache --virtual=run-deps \
    busybox nginx git ca-certificates curl \
    php${PHP_VER} php${PHP_VER}-fpm php${PHP_VER}-phar \
    php${PHP_VER}-pdo php${PHP_VER}-gd php${PHP_VER}-pgsql php${PHP_VER}-pdo_pgsql php${PHP_VER}-xmlwriter \
    php${PHP_VER}-mbstring php${PHP_VER}-intl php${PHP_VER}-xml php${PHP_VER}-curl php${PHP_VER}-simplexml \
    php${PHP_VER}-session php${PHP_VER}-tokenizer php${PHP_VER}-dom php${PHP_VER}-fileinfo php${PHP_VER}-ctype \
    php${PHP_VER}-json php${PHP_VER}-iconv php${PHP_VER}-pcntl php${PHP_VER}-posix php${PHP_VER}-zip php${PHP_VER}-exif php${PHP_VER}-openssl \
    tar xz

# Add user www-data for php-fpm.
# 82 is the standard uid/gid for "www-data" in Alpine.
RUN adduser -u 82 -D -S -G www-data www-data

# Copy root file system.
COPY --chown=www-data:www-data root /

# Add s6 overlay.
#ARG S6_OVERLAY_VERSION=3.1.5.0
#RUN curl -L -s https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz | tar -Jxpf - -C /
# Note: Tweak this line if you're running anything other than x86 AMD64 (64-bit).
#RUN curl -L -s https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz | tar -Jxpf - -C /
RUN curl -L -s https://github.com/just-containers/s6-overlay/releases/download/v1.19.1.1/s6-overlay-amd64.tar.gz | tar xvzf - -C /

# Add wait-for-it.sh
ADD https://raw.githubusercontent.com/Eficode/wait-for/master/wait-for /srv
RUN chmod 755 /srv/wait-for

# Expose Nginx ports.
EXPOSE 8080
EXPOSE 4443

# Expose default database credentials via ENV in order to ease overwriting.
ENV DB_NAME ttrss
ENV DB_USER ttrss
ENV DB_PASS ttrss

# Clean up.
RUN set -xe && apk del --progress --purge && rm -rf /var/cache/apk/* && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/init"]
