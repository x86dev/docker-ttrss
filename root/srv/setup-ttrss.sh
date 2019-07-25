#!/bin/sh

setup_nginx()
{
    if [ -z "$TTRSS_HOST" ]; then
        TTRSS_HOST=ttrss
    fi

    NGINX_CONF=/etc/nginx/nginx.conf

    if [ "$TTRSS_WITH_SELFSIGNED_CERT" = "1" ]; then
        # Install OpenSSL.
        apk update && apk add openssl

        if [ ! -f "/etc/ssl/private/ttrss.key" ]; then
            echo "Setup: Generating self-signed certificate ..."
            # Generate the TLS certificate for our Tiny Tiny RSS server instance.
            openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
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
        echo "Setup: !!! WARNING - No encryption (TLS) used - WARNING    !!!"
        echo "Setup: !!! This is not recommended for a production server !!!"
        echo "Setup:                You have been warned."

        # Turn off SSL.
        sed -i -e "s/listen\s*4443\s*;/listen 8080;/g" ${NGINX_CONF}
        sed -i -e "s/ssl\s*on\s*;/ssl off;/g" ${NGINX_CONF}
        sed -i -e "s/ssl_/#ssl_/g" ${NGINX_CONF}
    fi
}

setup_ttrss()
{
    if [ -z "$TTRSS_REPO_URL" ]; then
        TTRSS_REPO_URL=https://git.tt-rss.org/git/tt-rss.git
    fi

    if [ -z "$TTRSS_PATH" ]; then
    	TTRSS_PATH=/var/www/ttrss
    fi

    TTRSS_PATH_THEMES=${TTRSS_PATH}/themes.local
    TTRSS_PATH_PLUGINS=${TTRSS_PATH}/plugins.local

    if [ ! -d ${TTRSS_PATH} ]; then
        mkdir -p ${TTRSS_PATH}
        if [ -n "$TTRSS_GIT_TAG" ]; then
            echo "Setup: Setting up Tiny Tiny RSS '$TTRSS_GIT_TAG' ..."
            cd ${TTRSS_PATH}
            git init .
            git fetch --depth=1 ${TTRSS_REPO_URL} refs/tags/${TTRSS_GIT_TAG}:refs/tags/${TTRSS_GIT_TAG}
            git checkout tags/${TTRSS_GIT_TAG}
        else
            echo "Setup: Setting up Tiny Tiny RSS (latest revision) ..."
            git clone --depth=1 ${TTRSS_REPO_URL} ${TTRSS_PATH}
        fi

        mkdir -p ${TTRSS_PATH_PLUGINS}
        git clone --depth=1 https://github.com/sepich/tt-rss-mobilize.git ${TTRSS_PATH_PLUGINS}/mobilize
        git clone --depth=1 https://github.com/feediron/ttrss_plugin-feediron.git ${TTRSS_PATH_PLUGINS}/feediron

        mkdir -p ${TTRSS_PATH_THEMES}
        git clone --depth=1 https://github.com/levito/tt-rss-feedly-theme.git ${TTRSS_PATH_THEMES}/levito-feedly-git
        git clone --depth=1 https://github.com/Gravemind/tt-rss-feedlish-theme.git ${TTRSS_PATH_THEMES}/gravemind-feedly-git
    fi

    # Add initial config.
    cp ${TTRSS_PATH}/config.php-dist ${TTRSS_PATH}/config.php

    # Check if TTRSS_URL is undefined, and if so, use localhost as default.
    if [ -z ${TTRSS_URL} ]; then
        TTRSS_URL=localhost
    fi

    if [ "$TTRSS_WITH_SELFSIGNED_CERT" = "1" ]; then
        # Make sure the TTRSS protocol is https now.
        TTRSS_PROTO=https
    fi

    # If no protocol is specified, use http as default. Not secure, I know.
    if [ -z ${TTRSS_PROTO} ]; then
        TTRSS_PROTO=http
    fi

    # Add a leading colon (for the final URL) to the port.
    if [ -n "$TTRSS_PORT" ]; then
        TTRSS_PORT=:${TTRSS_PORT}
    fi

    # If we've been passed $TTRSS_SELF_URL as an env variable, then use that,
    # otherwise use the URL we constructed above.
    if [ -z "$TTRSS_SELF_URL" ]; then
  	    # Construct the final URL TTRSS will use.
   	    TTRSS_SELF_URL=${TTRSS_PROTO}://${TTRSS_URL}${TTRSS_PORT}/
    fi

    echo "Setup: URL is: $TTRSS_SELF_URL"

    # By default we want to reset the theme to the default one.
    if [ -z ${TTRSS_THEME_RESET} ]; then
        TTRSS_THEME_RESET=1
    fi

    # Patch URL path.
    sed -i -e 's@htt.*/@'"${TTRSS_SELF_URL}"'@g' ${TTRSS_PATH}/config.php

    # Check if single user mode is selected
    if [ "$TTRSS_SINGLEUSER" = true ]; then
        echo "Single User mode Selected"
        sed -i -e "s/.*define('SINGLE_USER_MODE'.*/define('SINGLE_USER_MODE', 'true');/g" ${TTRSS_PATH}/config.php
    fi

    # Enable additional system plugins.
    if [ -z ${TTRSS_PLUGINS} ]; then

        TTRSS_PLUGINS=

        # Only if SSL/TLS is enabled: af_zz_imgproxy (Loads insecure images via built-in proxy).
        if [ "$TTRSS_PROTO" = "https" ]; then
            TTRSS_PLUGINS=${TTRSS_PLUGINS}af_zz_imgproxy
        fi
    fi

    echo "Setup: Additional plugins: $TTRSS_PLUGINS"

    sed -i -e "s/.*define('PLUGINS'.*/define('PLUGINS', '$TTRSS_PLUGINS, auth_internal, note, updater');/g" ${TTRSS_PATH}/config.php

    # Export variables for sub shells.
    export TTRSS_PATH
    export TTRSS_PATH_PLUGINS
    export TTRSS_THEME_RESET
}

setup_db()
{
    echo "Setup: Database"
    php -f /srv/ttrss-configure-db.php
    php -f /srv/ttrss-configure-plugin-mobilize.php
}

setup_nginx
setup_ttrss
setup_db

echo "Setup: Applying updates ..."
/srv/update-ttrss.sh --no-start

echo "Setup: Done"
