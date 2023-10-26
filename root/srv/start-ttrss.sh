#!/bin/sh

set -e

# Call the setup script to make sure everything is ready to go.
/srv/setup-ttrss.sh --no-start

# Call the image's init script which in turn calls the s6 supervisor then.
/init
