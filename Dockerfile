# Using https://github.com/gliderlabs/docker-alpine, which in turn
# plus  https://github.com/just-containers/s6-overlay for a s6 Docker overlay
FROM gliderlabs/alpine
# Initially was based on work of Christian Lück <christian@lueck.tv>
LABEL description="A complete, self-hosted Tiny Tiny RSS (TTRSS) environment." \
      maintainer="Andreas Löffler <andy@x86dev.com>"

RUN set -xe && \
    apk update && apk upgrade && \
    apk add --no-cache --virtual=run-deps \
    nginx git ca-certificates curl \
    php5 php5-fpm php5-curl php5-dom php5-gd php5-json php5-mcrypt php5-pcntl \
    php5-pdo php5-pdo_pgsql php5-pgsql php5-pdo_mysql php5-mysql php5-mysqli php5-posix

# Add user www-data for php-fpm
# 82 is the standard uid/gid for "www-data" in Alpine
RUN adduser -u 82 -D -S -G www-data www-data

# Copy root file system
COPY root /

# Add s6 overlay
# Note: Tweak this line if you're running anything other than x86 AMD64 (64-bit)
RUN curl -L -s https://github.com/just-containers/s6-overlay/releases/download/v1.19.1.1/s6-overlay-amd64.tar.gz | tar xvzf - -C /

# expose Nginx ports
EXPOSE 8080
EXPOSE 4443

# expose default database credentials via ENV in order to ease overwriting
ENV DB_NAME ttrss
ENV DB_USER ttrss
ENV DB_PASS ttrss

# only run the setup once
RUN set -xe && /srv/setup-ttrss.sh

# clean up
RUN set -xe && apk del --progress --purge && rm -rf /var/cache/apk/*

ENTRYPOINT ["/init"]
