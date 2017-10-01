#!/bin/sh

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

update_theme_breeze()
{
	echo "Updating: Breeze theme"
	( cd ${TTRSS_PATH}/themes/breeze-git && git pull origin HEAD )

	# Link theme to TTRSS.
	ln -f -s ${TTRSS_PATH}/themes/breeze-git/breeze ${TTRSS_PATH}/themes/breeze
	ln -f -s ${TTRSS_PATH}/themes/breeze-git/breeze-dark.css ${TTRSS_PATH}/themes/breeze-dark.css
}

update_common()
{
    if [ -z "$MY_ROOT_UID" ]; then
        MY_ROOT_UID=0
    fi
    if [ -z "$MY_ROOT_GID" ]; then
        MY_ROOT_GID=0
    fi

    echo "Updating: Updating permissions"
    for CUR_DIR in /etc/nginx /etc/php5 /var/lib/nginx /etc/services.d; do
        chown -R ${MY_ROOT_UID}:${MY_ROOT_GID} ${CUR_DIR}
    done

    chown -R www-data:www-data ${TTRSS_PATH}

    echo "Updating: Updating permissions done"
}

update_ttrss
update_plugin_mobilize
update_plugin_newsplus
update_plugin_feediron
update_theme_feedly
update_theme_breeze
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
