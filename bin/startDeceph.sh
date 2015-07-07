#!/usr/bin/env bash 

ROOT_MODE=1
DEPLOY_MODE="init"
# init, apend or exit

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`
. deceph.conf.sh


init_mon(){
    echo "check mon nodes"
    count=`echo $init_mon | tr ";" "\n" | wc -l`
    echo "$count"
    if [ "$DEPLOY_MODE" == "init" ] && [ "$count" -lt 3 ];then
        echo "you must have least 3 node to init mon and mds node."
    else
        if [ -e "/tmp/multi_mon_nodes" ]; then
          rm /tmp/multi_mon_nodes
        fi
        touch /tmp/multi_mon_nodes
        for x in `echo $init_mon | tr ";" "\n"`;
        do
          echo $x >> /tmp/multi_mon_nodes;
        done
    fi

    ./deployCeph.sh init mon /tmp/multi_mon_nodes

    for x in `echo $init_mon | tr ";" "\n"`;
    do
        ssh $x "service ceph start" & 
    done
}

add_mon(){
    echo "add mon"
    

}

multi_osd_add(){
    echo "multi osd add"
    if [ -e "/tmp/multi_osd_nodes" ]; then
      rm /tmp/multi_osd_nodes
    fi
    touch /tmp/multi_osd_nodes
    for x in `echo $deploy_osd_list | tr ";" "\n"`;
    do
      echo $x >> /tmp/multi_osd_nodes;
    done

    ./deployCeph.sh init osd /tmp/multi_osd_nodes
    
    if [ "$DEPLOY_MODE" == "init" ];then
      for x in `echo $init_mon | tr ";" "\n"`;
      do
        ssh $x "service ceph stop" 
      done
      sleep 3
      for x in `echo $init_mon | tr ";" "\n"`;
      do
        ssh $x "service ceph start" &
      done
    fi
}

add_radosgw(){
    echo "check radosgw node"
    if [ -e "/tmp/multi_radosgw_nodes" ]; then
      rm /tmp/multi_radosgw_nodes
    fi
    touch /tmp/multi_radosgw_nodes
    for x in `echo $deploy_radosgw_list | tr ";" "\n"`;
    do
      echo $x >> /tmp/multi_radosgw_nodes;
    done

    ./deployRadosgw.sh deploy /tmp/multi_radosgw_nodes
}

main(){
    DEPLOY_MODE=$1
    if [ "$DEPLOY_MODE" == "" ]; then
       echo "using: init or apend"
       exit 0
    fi
    if [ "$DEPLOY_MODE" == "init" ]; then
      echo "start to deploy ceph..."
      init_mon
      multi_osd_add
      add_radosgw
    elif [ "$DEPLOY_MODE" == "apend" ]; then 
      add_mon
      multi_osd_add
      add_radosgw
    fi
    
}

main $1

