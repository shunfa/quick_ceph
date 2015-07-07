#!/bin/sh
exec /usr/bin/radosgw -c /etc/ceph/ceph.conf -n client.radosgw.decephgw 
touch /tmp/radosgw-started-flag
