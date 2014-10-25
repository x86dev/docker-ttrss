FROM phusion/baseimage
# Initially was based on work of Christian Lück <christian@lueck.tv>
MAINTAINER Andreas Löffler <andy@x86dev.com>

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
  nginx git ca-certificates php5-fpm php5-cli php5-curl php5-gd php5-json \
  php5-pgsql
# php5-mysql

# add ttrss as the only nginx site
ADD ttrss-nginx.conf /etc/nginx/sites-available/ttrss
RUN ln -s /etc/nginx/sites-available/ttrss /etc/nginx/sites-enabled/ttrss
RUN rm /etc/nginx/sites-enabled/default

# patch php5-fpm configuration so that it does not daemonize itself. This is
# needed so that runit can watch its state and restart it if it crashes etc.
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf

# patch the php-fpm's listening method to _always_ use a unix socket
# note: if not done correctly this will result in a "502 Bad Gateway" error
#       (see /var/log/nginx/error.log for more information then)
RUN sed -i -e "s/listen\s*=.*/listen = \/var\/run\/php5-fpm.sock/g" /etc/php5/fpm/pool.d/www.conf

# install ttrss and patch configuration
RUN git clone https://github.com/gothfox/Tiny-Tiny-RSS.git /var/www/ttrss
WORKDIR /var/www/ttrss
RUN cp config.php-dist config.php
RUN sed -i -e "/'SELF_URL_PATH'/s/ '.*'/ 'http:\/\/localhost\/'/" config.php

# install Feedly theme
RUN git clone https://github.com/levito/tt-rss-feedly-theme.git
RUN ln -s /var/www/ttrss/tt-rss-feedly-theme/feedly /var/www/ttrss/themes/feedly
RUN ln -s /var/www/ttrss/tt-rss-feedly-theme/feedly.css /var/www/ttrss/themes/feedly.css

# install ttrss-mobilize plugin
RUN git clone https://github.com/sepich/tt-rss-mobilize.git /var/www/ttrss/plugins/mobilize
ADD ttrss-plugin-mobilize.pgsql /var/www/ttrss/plugins/mobilize/ttrss-plugin-mobilize.pgsql

# patch ttrss-mobilize plugin for getting it to work
RUN sed -i -e "s/<? */<?php/" /var/www/ttrss/plugins/mobilize/m.php

# install tt-rss-newsplus-plugin (for use with News+ on Android)
RUN git clone https://github.com/hrk/tt-rss-newsplus-plugin.git /var/www/ttrss/plugins/api_newsplus
RUN ln -s /var/www/ttrss/plugins/api_newsplus/api_newsplus/init.php /var/www/ttrss/plugins/api_newsplus/init.php

# apply ownership of ttrss + addons to www-data
RUN chown www-data:www-data -R /var/www

# expose nginx HTTPS port
EXPOSE 443

# expose default database credentials via ENV in order to ease overwriting
ENV DB_NAME ttrss
ENV DB_USER ttrss
ENV DB_PASS ttrss

# always re-configure database with current ENV when RUNning container, then monitor all services
## @todo pack the scripts to a .zip, ADD this and RUN it in setup.sh. Later.
ADD utils.php /root/utils.php
ADD configure-db.php /root/configure-db.php
ADD configure-plugin-mobilize.php /root/configure-plugin-mobilize.php

# Enable additional system plugins: api_newsplus
RUN sed -i -e "s/.*define('PLUGINS'.*/define('PLUGINS', 'api_newsplus, auth_internal, note, updater');/g" /var/www/ttrss/config.php

RUN mkdir /etc/service/nginx
ADD service-nginx.sh /etc/service/nginx/run

RUN mkdir /etc/service/php5-fpm
ADD service-php5-fpm.sh /etc/service/php5-fpm/run

RUN mkdir /etc/service/ttrss-update
ADD service-ttrss-update.sh /etc/service/ttrss-update/run

RUN mkdir /root/certs
VOLUME /root/certs

ADD 10_ttrss.sh /etc/my_init.d/10_ttrss.sh
CMD /sbin/my_init
EXPOSE 22
