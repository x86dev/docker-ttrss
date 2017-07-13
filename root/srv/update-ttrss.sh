#!/bin/sh
set -e

TTRSS_PATH=/var/www/ttrss

update_ttrss()
{
    if [ -n "$TTRSS_GIT_TAG" ]; then
        echo "Updating Tiny Tiny RSS disabled (using tag '$TTRSS_GIT_TAG')"
        return
    fi

    echo "Updating: Tiny Tiny RSS"
    ( cd ${TTRSS_PATH} && git pull origin HEAD )
}

update_plugin_mobilize()
{
    echo "Updating: Mobilize plugin"
    ( cd ${TTRSS_PATH}/plugins/mobilize && git pull origin HEAD )

    # Patch ttrss-mobilize plugin for getting it to work.
    sed -i -e "s/<?$/<?php/g" ${TTRSS_PATH}/plugins/mobilize/m.php
}

# For use with News+ on Android. Buy the Pro version -- I love it!
update_plugin_newsplus()
{
    echo "Updating: News+ plugin"
    ( cd ${TTRSS_PATH}/plugins/api_newsplus && git pull origin HEAD )

    # Link plugin to TTRSS.
    ln -f -s ${TTRSS_PATH}/plugins/api_newsplus/api_newsplus/init.php ${TTRSS_PATH}/plugins/api_newsplus/init.php
}

update_plugin_feediron()
{
    echo "Updating: FeedIron"
    ( cd ${TTRSS_PATH}/plugins/feediron && git pull origin HEAD )
}

update_theme_feedly()
{
    echo "Updating: Feedly theme"
    ( cd ${TTRSS_PATH}/themes/feedly-git && git pull origin HEAD )

    # Link theme to TTRSS.
    ln -f -s ${TTRSS_PATH}/themes/feedly-git/feedly ${TTRSS_PATH}/themes/feedly
    ln -f -s ${TTRSS_PATH}/themes/feedly-git/feedly.css ${TTRSS_PATH}/themes/feedly.css
}

update_common()
{
    echo "Updating: Updating permissions"
    for dir in /etc/nginx /etc/php5 /var/log /var/lib/nginx /tmp /etc/services.d; do
    if $(find $dir ! -user $UID -o ! -group $GID | egrep '.' -q); then
        echo "Updating: Updating permissions in $dir..."
        chown -R $UID:$GID $dir
    else
        echo "Updating: Permissions in $dir are correct"
    fi
    done

    chown -R www-data:www-data ${TTRSS_PATH}

    echo "Updating: updating permissions done"
}

echo "Update: Updating rolling release ..."
echo "Update: Stopping all ..."

update_ttrss
update_plugin_mobilize
update_plugin_newsplus
update_plugin_feediron
update_theme_feedly
update_common

echo "Update: Done"

if [ "$1" != "--no-start" ]; then
    echo "Update: Starting all ..."
fi
if [ "$1" = "--wait-exit" ]; then
    UPDATE_WAIT_TIME=$2
    if [ -z "$UPDATE_WAIT_TIME" ]; then
        UPDATE_WAIT_TIME=24h # Default is to check every day (24 hours).
    fi
    echo "Update: Sleeping for $UPDATE_WAIT_TIME ..."
    sleep ${UPDATE_WAIT_TIME}
fi
