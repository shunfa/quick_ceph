#!/bin/bash

#set -e
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

. $bin/deployFuns.sh

#echo "deploy radosgw"
sel_hostname=""
radosgw_count=2

# $1=deploy no.
# 1. Select Node
# 2. check ssh
# 3. R: get radosgw no, get default ports
# 4. R: pkg install, edit ServerName
# 5. gen conf files at /tmp/hostname-rgw/ (rgw.conf, s3gw.fcgi), write to radosgw_node
# 6. edit ceph.conf
# 7. auth
    #$ sudo ceph-authtool -C -n client.radosgw.gateway --gen-key /etc/ceph/keyring.radosgw.gateway
    #$ sudo ceph-authtool -n client.radosgw.gateway --cap mon 'allow rw' --cap osd 'allow rwx' /etc/ceph/keyring.radosgw.gateway
    #$ sudo ceph auth add client.radosgw.gateway --in-file=keyring.radosgw.gateway
# 8. sync files
# 9. R: ensite(mod) and dissite(mod)
#10. R: start Radosgw

print_usage(){
    echo "
add mode:
add radosgw

====================

deploy mode:
deploy <node_file>

"

}

add_radosgw(){
# $1=hostname
    sel_hostname=$1
    if [ "$sel_hostname" == "" ]; then
        select_node
        sel_hostname=`cat /tmp/res`
    fi
    sshkey_manager
    checkIP $sel_hostname
    pkg_radosgw_check_n_install $sel_hostname
    edit_apache_conf $sel_hostname
    get_radosgw_no $sel_hostname
    rgw_no=`cat /tmp/res`
    create_rgw_conf $sel_hostname $rgw_no
    write_service_node $sel_hostname
    mod_setup $sel_hostname
    deploy_confs $sel_hostname $rgw_no
    sync_multi_nodes
    start_up $sel_hostname
}

main (){
#    echo "command: $1 $2"
    unset count
    count=1

    if [ "$1" == "add" ] && [ "$2" == "radosgw" ] ; then
      echo "init radosgw..."
      add_radosgw $3
      elif [ "$1" == "deploy" ] && [ -e $2 ] ; then
        for nodes in `cat $2`
        do
          add_radosgw `ssh -o StrictHostKeyChecking=no $nodes "hostname -f"`
          sync_multi_nodes
          start_up $sel_hostname
        done 
      else
        print_usage
    fi
}

main $1 $2 $3 $4
