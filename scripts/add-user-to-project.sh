#!/usr/bin/env bash

set -o errexit
set -o pipefail

KOLLA_DEBUG=${KOLLA_DEBUG:-0}
KOLLA_CONFIG_PATH=${KOLLA_CONFIG_PATH:-/etc/kolla}

KOLLA_OPENSTACK_COMMAND=openstack

if [[ $KOLLA_DEBUG -eq 1 ]]; then
    set -o xtrace
    KOLLA_OPENSTACK_COMMAND="$KOLLA_OPENSTACK_COMMAND --debug"
fi

# This script is meant to be run to add a user to an existing project.

# Sanitize language settings to avoid commands bailing out
# with "unsupported locale setting" errors.
unset LANG
unset LANGUAGE
LC_ALL=C
export LC_ALL
for i in curl openstack; do
    if [[ ! $(type ${i} 2>/dev/null) ]]; then
        if [ "${i}" == 'curl' ]; then
            echo "Please install ${i} before proceeding"
        else
            echo "Please install python-${i}client before proceeding"
        fi
        exit
    fi
done

# Test for clouds.yaml
if [[ ! -f ${KOLLA_CONFIG_PATH}/clouds.yaml ]]; then
    echo "${KOLLA_CONFIG_PATH}/clouds.yaml is missing."
    echo " Did your deploy finish successfully?"
    exit 1
fi

# Specify clouds.yaml file to use
export OS_CLIENT_CONFIG_FILE=${KOLLA_CONFIG_PATH}/clouds.yaml

# Select admin account from clouds.yaml
export OS_CLOUD=kolla-admin



PROJECT_NAME=${1:-kubernetes}
USER_NAME=${2:-franz}
USER_ROLE=${3:-manager}


# create the user if they don't exist:
exists=$(cut -d " " -f4 <<< $($KOLLA_OPENSTACK_COMMAND user list | grep ${USER_NAME}))
if ! [ -n "$exists" ]; then
    read -sp "Enter password for user ${USER_NAME}: " PASSWORD
    $KOLLA_OPENSTACK_COMMAND user create --password ${PASSWORD} ${USER_NAME}
fi

# add that user to the project above as $USER_ROLE
$KOLLA_OPENSTACK_COMMAND role add --user ${USER_NAME} --project ${PROJECT_NAME} ${USER_ROLE}

