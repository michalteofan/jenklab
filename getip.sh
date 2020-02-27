#!/bin/bash

LST_EXPECTED_ARGS=1
if [ $# -ne $LST_EXPECTED_ARGS ]; then
        echo "Usage:\n $0 <INSTANCE_NAME>"
	exit
fi

LST_DBSERVER=$1
LST_IPADDR=$(source /ostackrc/pvcjenkinsrc; openstack-3 server list -f value -c Name -c Networks | grep -w $LST_DBSERVER | awk '{ split($2, v, "="); print v[2]}')
echo $LST_IPADDR
exit 0
