#!/bin/bash

echo "manager"

all_node_collection(){
    collect_ip mon_node
    collect_ip mds_node
    collect_ip osd_node
}
collect_ip(){
# $1=file name
#    echo "" > ../conf/all_node
    for node in `cat ../conf/$1`
    do
      echo $node >> ../conf/all_node
    done
    sort ../conf/all_node | uniq > /tmp/all_node
    cp /tmp/all_node ../conf/all_node
}

start_mon(){
# $1=hostname
    ssh -o StrictHostKeyChecking=no $1 "ceph-mon -i $1"
    ssh -o StrictHostKeyChecking=no $1 "ceph-mds -i $1"
}

start_all_nodes(){
# start all nodes
# $1=mon, osd
    echo "start all mon nodes"
    for node in `cat ../conf/$1_node`
    do
      if [ "$1" == "mon" ]; then
        start_mon $node
      fi
      if [ "$1" == "osd" ]; then
        ssh -o StrictHostKeyChecking=no $node "service ceph start"
      fi
    done
}

stop_all_nodes(){
    echo "stop all nodes"
    # start all nodes
# $1=mon, osd
    echo "start all mon nodes"
    for node in `cat ../conf/all_node`
    do
      ssh -o StrictHostKeyChecking=no $node "service ceph stop"
    done
}

main(){
    all_node_collection
    if [ "$1" == "start-all" ]; then
      if [ "$2" == "mon" ] || [ "$2" == "osd" ] ; then
	start_all_nodes $2
      fi
    fi
    if [ "$1" == "stop-all" ]; then
	stop_all_nodes
    fi
}

main $1 $2 $3
