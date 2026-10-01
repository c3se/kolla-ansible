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

# This script is meant to be run to create a new project 


IP_VERSION=${IP_VERSION:-4}

DEMO_NET_CIDR=${DEMO_NET_CIDR:-'10.0.0.0/24'}
DEMO_NET_GATEWAY=${DEMO_NET_GATEWAY:-'10.0.0.1'}
DEMO_NET_DNS=${DEMO_NET_DNS:-'8.8.8.8'}

# This EXT_NET_CIDR is your public network,that you want to connect to the internet via.
ENABLE_EXT_NET=${ENABLE_EXT_NET:-1}
EXT_NET_CIDR=${EXT_NET_CIDR:-'129.16.122.0/23'}
EXT_NET_RANGE=${EXT_NET_RANGE:-'start=129.16.122.100,end=129.16.122.200'}
EXT_NET_GATEWAY=${EXT_NET_GATEWAY:-'129.16.122.1'}

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


# create a project
PROJECT_NAME=${1:-kubernetes}
openstack project create $PROJECT_NAME

# Get project ID and tenant IDs
PROJECT_ID=$(cut -d " " -f2 <<< $(${KOLLA_OPENSTACK_COMMAND} project list | grep ${PROJECT_NAME}))
SEC_GROUP=$($KOLLA_OPENSTACK_COMMAND security group list --project ${PROJECT_ID} | awk '/ default / {print $2}')

# Sec Group Config
$KOLLA_OPENSTACK_COMMAND security group rule create --ingress --ethertype IPv${IP_VERSION} \
    --protocol icmp ${SEC_GROUP}
$KOLLA_OPENSTACK_COMMAND security group rule create --ingress --ethertype IPv${IP_VERSION} \
    --protocol tcp --dst-port 22 ${SEC_GROUP}
# Open heat-cfn so it can run on a different host
$KOLLA_OPENSTACK_COMMAND security group rule create --ingress --ethertype IPv${IP_VERSION} \
    --protocol tcp --dst-port 8000 ${SEC_GROUP}
$KOLLA_OPENSTACK_COMMAND security group rule create --ingress --ethertype IPv${IP_VERSION} \
    --protocol tcp --dst-port 8080 ${SEC_GROUP}


echo Configuring neutron.

ROUTER_NAME=Router-${PROJECT_NAME}
NETWORK_NAME=Network-${PROJECT_NAME}
SUBNET_NAME=Subnet-${PROJECT_NAME}

$KOLLA_OPENSTACK_COMMAND router create --project ${PROJECT_NAME} ${ROUTER_NAME}

SUBNET_CREATE_EXTRA=""

if [[ $IP_VERSION -eq 6 ]]; then
    # NOTE(yoctozepto): Neutron defaults to "unset" (external) addressing for IPv6.
    # The following is to use stateful DHCPv6 (RA for routing + DHCPv6 for addressing)
    # served by Neutron Router and DHCP services.
    # Setting this for IPv4 errors out instead of being ignored.
    SUBNET_CREATE_EXTRA="${SUBNET_CREATE_EXTRA} --ipv6-ra-mode dhcpv6-stateful"
    SUBNET_CREATE_EXTRA="${SUBNET_CREATE_EXTRA} --ipv6-address-mode dhcpv6-stateful"
fi

# add private network
$KOLLA_OPENSTACK_COMMAND network create --project ${PROJECT_NAME} ${NETWORK_NAME}
$KOLLA_OPENSTACK_COMMAND subnet create --project ${PROJECT_NAME} \
			 --ip-version 4 \
			 --subnet-range '10.0.1.0/24' \
			 --network ${NETWORK_NAME} \
			 --gateway '10.0.1.1' \
			 --dns-nameserver '8.8.8.8' \
			 ${SUBNET_NAME}

$KOLLA_OPENSTACK_COMMAND router add subnet ${ROUTER_NAME} ${SUBNET_NAME}

if [[ $ENABLE_EXT_NET -eq 1 ]]; then
#    $KOLLA_OPENSTACK_COMMAND network create --external \
#			     --provider-physical-network physnet1 \
#			     --provider-network-type vlan \
#			     --provider-segment 12 \
#			     public
#			     #--share \
#    $KOLLA_OPENSTACK_COMMAND subnet create \
#			     --ip-version ${IP_VERSION} \
#			     --network public \
#			     --subnet-range ${EXT_NET_CIDR} \
#			     --gateway ${EXT_NET_GATEWAY} \
#			     public-subnet
#			     #--allocation-pool ${EXT_NET_RANGE} \

    if [[ $IP_VERSION -eq 4 ]]; then
        $KOLLA_OPENSTACK_COMMAND router set --external-gateway dev-public ${ROUTER_NAME}
    else
        # NOTE(yoctozepto): In case of IPv6 there is no NAT support in Neutron,
        # so we have to set up native routing. Static routes are the simplest.
        # We need a static IP address for the router to demo.
        $KOLLA_OPENSTACK_COMMAND router set --external-gateway dev-public \
            --fixed-ip subnet=${SUBNET_NAME},ip-address=${EXT_NET_DEMO_ROUTER_ADDR} \
            ${ROUTER_NAME}
    fi
fi

# get more useful quota
openstack quota set --cores 128 \
	            --ram 256000 \
		    --instances 20 \
		    --floating-ips 10 \
		    ${PROJECT_ID}

