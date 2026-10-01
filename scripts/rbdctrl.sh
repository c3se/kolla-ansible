#!/usr/bin/bash

KEYRING=/etc/kolla/config/ceph-combined.keyring
CEPH_CONFIG=/etc/kolla/config/ceph.conf
POOL=volumes
RBD_COMMAND="ls"

print_usage() {
    cat <<EOF

NAME

   rbdctrl -- A bash programme to list and manipulate images in ceph storage pools.

SYNOPSIS

   rbdctl [options] rbd-command [rbd-command-specific options]

DESCRIPTION

   In essence, this is a wrapper around Ceph's "rbd". It provides the required keyring file and 
   ceph config files for ease of use. It also "knows" about the cinder pool names and associated 
   IDs. Currently supported/known pool and IDs are:
   Pool                           ID
   cirrus-cec-1.cinder-volumes    cirrus-cec-1.cinder
   cirrus-cec-1.cinder-backup     cirrus-cec-1.cinder-backup
   cirrus-cec-1.glance-images     cirrus-cec-1.glance
   cirrus-cec-1.ephemeral-vms     cirrus-cec-1.nova

OPTIONS

   -p pool        Pool to be listed/managed. Can be any of [volumes, backup, glance, nova]. 
                  Defaults to ${POOL}.
   -k keyring     Path to keyring. 
                  Defaults to ${KEYRING}.
   -c cephConfig  Path to ceph config file. 
                  Defaults to ${CEPH_CONFIG}.
   -j rbdCommand  rbd positional argument. Run 'rbd help' to get a full list. 
                  Defaults to 'ls'. 
                  NOTE: Composite positional arguments need to be provided within quotes. E.g.:
                   rbdctrl -p glance -j "pool stats"
   -h             Display this very useful help.

EOF
}

while getopts "p:k:c:hj:" opt;do
    case ${opt} in
	p) POOL=${OPTARG};;
	k) KEYRING=${OPTARG};;
	c) CEPH_CONFIG=${OPTARG};;
	j) RBD_COMMAND=${OPTARG};;
	h) print_usage;;
	*) echo "ERROR: Unknow option. Check the help with -h."
	   exit 0;;
    esac
done

case ${POOL} in
    volumes) ID=cirrus-cec-1.cinder
	     POOL=cirrus-cec-1.cinder-volumes;;
    backup)  ID=cirrus-cec-1.cinder-backup
	     POOL=cirrus-cec-1.cinder-backup;;
    glance)  ID=cirrus-cec-1.glance
	     POOL=cirrus-cec-1.glance-images;;
    nova)    ID=cirrus-cec-1.nova
	     POOL=cirrus-cec-1.ephemeral-vms;;
    *) echo "ERROR: Unkown pool name. Check the help with -h."
       exit 0;;
esac

rbd -k ${KEYRING} -c ${CEPH_CONFIG} --id ${ID} -p ${POOL} ${RBD_COMMAND}
