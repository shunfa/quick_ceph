#!/bin/bash
echo "boot script"
img_no=`hostname -f | awk '{split($1,a,"-")};{print a[2]}'`
img_name="pos$img_no".img
echo "$img_name"
mount /vagrant/ceph-img/$img_name /var/lib/ceph