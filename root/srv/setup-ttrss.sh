#!/bin/sh

set -e

setup_nginx()
{
    if [ -z "$TTRSS_HOST" ]; then
        TTRSS_HOST=ttrss
    fi

    NGINX_CONF=/etc/nginx/nginx.conf

    if [ "$TTRSS_SSL_ENABLED" = "1" ]; then
        # Install OpenSSL.
        apk update && apk add openssl
        
        if [ ! -f "/etc/ssl/private/ttrss.key" ]; then
            echo "Setup: Generating self-signed certificate ..."
            # Generate the TLS certificate for our Tiny Tiny RSS server instance.
            openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
                -subj "/C=US/ST=World/L=World/O=$TTRSS_HOST/CN=$TTRSS_HOST" \
                -keyout "/etc/ssl/private/ttrss.key" \
                -out "/etc/ssl/certs/ttrss.crt"
        fi

        # Turn on SSL.
        sed -i -e "s/listen\s*8080\s*;/listen 4443;/g" ${NGINX_CONF}
        sed -i -e "s/ssl\s*off\s*;/ssl on;/g" ${NGINX_CONF}
        sed -i -e "s/#ssl_/ssl_/g" ${NGINX_CONF}

        # Set permissions.
        chmod 600 "/etc/ssl/private/ttrss.key"
        chmod 600 "/etc/ssl/certs/ttrss.crt"
    else
        echo "Setup: !!! WARNING !!! Turning OFF SSL/TLS !!! WARNING !!!"
        echo "Setup: This is not recommended for a production server. You have been warned."
        
        # Turn off SSL.
        sed -i -e "s/listen\s*4443\s*;/listen 8080;/g" ${NGINX_CONF}
        sed -i -e "s/ssl\s*on\s*;/ssl off;/g" ${NGINX_CONF}
        sed -i -e "s/ssl_/#ssl_/g" ${NGINX_CONF}
    fi
}

setup_ttrss()
{
    TTRSS_PATH=/var/www/ttrss

    if [ ! -d ${TTRSS_PATH} ]; then
        mkdir -p ${TTRSS_PATH}
        git clone --depth=1 https://tt-rss.org/gitlab/fox/tt-rss.git ${TTRSS_PATH}
        git clone --depth=1 https://github.com/sepich/tt-rss-mobilize.git ${TTRSS_PATH}/plugins/mobilize
        git clone --depth=1 https://github.com/hrk/tt-rss-newsplus-plugin.git ${TTRSS_PATH}/plugins/api_newsplus
        git clone --depth=1 https://github.com/m42e/ttrss_plugin-feediron.git ${TTRSS_PATH}/plugins/feediron
        git clone --depth=1 https://github.com/levito/tt-rss-feedly-theme.git ${TTRSS_PATH}/themes/feedly-git
    fi

    # Add initial config.
    cp ${TTRSS_PATH}/config.php-dist ${TTRSS_PATH}/config.php

    # Patch URL path.
    if [ "$TTRSS_SSL_ENABLED" = "1" ]; then
        sed -i -e 's@htt.*/@'"${SELF_URL_PATH-https://localhost/}"'@g' ${TTRSS_PATH}/config.php
    else
        sed -i -e 's@htt.*/@'"${SELF_URL_PATH-http://localhost/}"'@g' ${TTRSS_PATH}/config.php
    fi

    # Enable additional system plugins: api_newsplus.
    sed -i -e "s/.*define('PLUGINS'.*/define('PLUGINS', 'api_newsplus, auth_internal, note, updater');/g" ${TTRSS_PATH}/config.php
}

echo "Setup: Installing Tiny Tiny RSS ..."
setup_ttrss
setup_nginx

echo "Setup: Applying updates ..."
/srv/update-ttrss.sh --no-start

echo "Setup: Done"
