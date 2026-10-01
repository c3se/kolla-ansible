#!/usr/bin/env bash

firstuser=1
lastuser=20

for n in `seq -w $firstuser $lastuser`; do
    openstack project create seminar${n}
    openstack user create --password seminar${n}-user${n} user${n}
    openstack role add --user user${n} --project seminar${n} member
    openstack quota set --gigabytes 32 seminar${n}
    openstack share quota set --gigabytes 32 seminar${n}
    openstack role add load-balancer_member --user user${n} --project seminar${n}
done

