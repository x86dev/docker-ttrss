#!/bin/sh

set -eu
set -x

php /root/configure-db.php
php /root/configure-plugin-mobilize.php

# Generate the TLS certificate for our Tiny Tiny RSS server instance.
if [ -f /etc/ssl/private/ttrss.key ] && [ -f /etc/ssl/certs/ttrss.cert ]
then
  if [ ! -f /root/certs/key ] && [ ! -f /root/certs/cert ]
  #Backward compatibility
  then
    ln -s /etc/ssl/private/ttrss.key /root/certs/key 
    ln -s /etc/ssl/certs/ttrss.cert /root/certs/cert 
  fi
else
  if [ ! -f /root/certs/key ] && [ ! -f /root/certs/cert ]
  then
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=US/ST=World/L=World/O=ttrss/CN=ttrss" \
        -keyout "/root/certs/key" \
        -out "/root/certs/cert"
  fi

  ln -s /root/certs/key /etc/ssl/private/ttrss.key
  ln -s /root/certs/cert /etc/ssl/certs/ttrss.cert
fi

chmod 600 -R "/root/certs"
chmod 600 "/etc/ssl/private/ttrss.key"
chmod 600 "/etc/ssl/certs/ttrss.cert"
