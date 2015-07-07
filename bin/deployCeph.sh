#!/usr/bin/env bash 

ROOT_MODE=1
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`
exe_path=`dirname $bin`

if [ "`id -u`" != "0" ]; then
   echo `whoami` > /tmp/username
fi

if [ "$ROOT_MODE" -eq 1  ]; then
    [ "`id -u`" != "0" ] && exec sudo su -c "$0" "$@"    
fi

ssh_key_manage(){

    echo "check ssh"
    if [ ! -e /root/.ssh/id_rsa.pub ]; then
        ssh-keygen
    fi
    # login without passwd
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

    # root login
    # "yes" replace "without-password'
    sed -i 's/without-password/yes/g' /etc/ssh/sshd_config
    # restart ssh
    service ssh restart
}

check_and_install_package(){
# $1=ip or hostname
    address=$1
    if [ "$address" == "" ]; then
      address="127.0.0.1"
    fi
    echo "check ceph package"
    if [ "`ssh -o StrictHostKeyChecking=no $address "which ceph"`" == "" ];then
      echo "install ceph..."
      ssh -o StrictHostKeyChecking=no $address "apt-get -y update"
      if [ "`ssh -o StrictHostKeyChecking=no $address "apt-cache search ceph"`" == "" ];then
        echo "add ceph package"
        ssh -o StrictHostKeyChecking=no $address "wget -q -O- https://raw.github.com/ceph/ceph/master/keys/release.asc | sudo apt-key add -"
        ssh -o StrictHostKeyChecking=no $address "echo deb http://ceph.com/debian/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list"
        ssh -o StrictHostKeyChecking=no $address "apt-get -y update"
      fi
#      ssh -o StrictHostKeyChecking=no $address "apt-get -y install ceph ceph-mds"
      ssh -o StrictHostKeyChecking=no $address "apt-get -y install ceph ceph-mds apache2 radosgw radosgw-agent libapache2-mod-fastcgi"
    fi

    if [ "`ssh -o StrictHostKeyChecking=no $address "which ceph"`" == "" ];then
      echo "Install ceph package fail, please check your network setting and reinstall. "
      exit 0;
    fi
}

add_mon_setting(){
# $1 = hostname, $2 = IP Addrsss
    echo "[mon.$1]
\\\       host = $1
\\\       mon addr = $2:6789
\\\
" > /tmp/mon_tmp
    write_setting mon /tmp/mon_tmp $1
    ssh -o StrictHostKeyChecking=no $2 "mkdir -p /var/lib/ceph/mon/ceph-$1"
}

add_mds_setting(){
# $1 = hostname
    echo "[mds.$1]
\\\       host = $1
\\\
" > /tmp/mds_tmp
    write_setting mds /tmp/mds_tmp $1
    ssh -o StrictHostKeyChecking=no $2 "mkdir -p /var/lib/ceph/mds/ceph-$1"
}

add_osd_setting(){
# $1 = hostname, $2 = osd_no
    echo "[osd.$2]
\\\       host = $1
\\\
" > /tmp/osd_tmp
    write_setting osd /tmp/osd_tmp $1
    ssh -o StrictHostKeyChecking=no $1 "mkdir -p /var/lib/ceph/osd/ceph-$2"
#    echo "init osd..."
#    sleep 5
#    ssh -o StrictHostKeyChecking=no $1 "ceph-osd -i $2 --mkfs --mkkey"
}

add_radosgw_setting(){
# $1 = hostname, $2 = key name, ex: radosgw.gateway
    echo "[client.$2]
host = $1
keyring = /etc/ceph/keyring.$2
rgw socket path = /tmp/radosgw.sock
log file = /var/log/ceph/radosgw.log

"
}

init_conf(){
    echo "init conf"
    cp $exe_path/conf/ceph.conf.temp /etc/ceph/ceph.conf
}

select_eth(){
#   echo "我們偵測到您的機器有以下網路裝置，請輸入您要設定的mon及mds節點位址："
    eth_devs=`ifconfig -s -a | awk '{print $1}'`
    arr_dev=""
    count_i=1
    for dev in $eth_devs
    do
      if [  "$dev" != "Iface" ]; then
        ip_address=$(/sbin/ifconfig $dev | grep "inet addr" | awk '{print $2}' | sed "s/addr://g")
        if [ "$ip_address" != ""  ]; then
          echo "$count_i: $dev-$ip_address"
          arr_dev="$arr_dev $dev"
          count_i=$(($count_i+1))
        fi
      fi
    done
  
    #co_i=1
    read -p "我們偵測到您的機器有以上網路裝置，請輸入您要設定的mon及mds節點位址：" co_i  
    if [ "$co_i" != "" ];then
      choice_dev=$(echo $arr_dev | awk '{print $'$co_i'}')
      choice_ip=$(/sbin/ifconfig $choice_dev | grep "inet addr" | awk '{print $2}' | sed "s/addr://g")
      add_mon_setting `hostname -f` $choice_ip
      add_mds_setting `hostname -f`
      edit_hosts $choice_ip `hostname -f`
    fi
}

write_setting(){
# $1=service name(e.g. mon, mds, osd), $2=message, $3=hostname    
    echo "Write setting to conf file..."
    editLineNo=$(cat -n /etc/ceph/ceph.conf | grep "$1-section-end" | awk '{print $1}')
    editLineNo=$((editLineNo-1))

    exec < $2
    sed -i ''$editLineNo'a\\' /etc/ceph/ceph.conf
    editLineNo=$((editLineNo+1))
    while read line
    do
      sed -i ''$editLineNo'a'"$line"'' /etc/ceph/ceph.conf
      editLineNo=$((editLineNo+1))
    done
    echo $3 >> $exe_path/conf/$1_node
}

edit_hosts(){
#   $1=ip address
    echo "edit hosts"
    editLineNo=$(cat -n /etc/hosts | grep `hostname` | grep "127.0.1.1" | awk '{print $1}')
    if [ "$editLineNo" != "" ]; then
      sed -i ''$editLineNo'd' /etc/hosts 
    fi
    if [ "`cat /etc/hosts | grep $1 | grep $2`" == ""  ]; then
      echo "## ceph-add
$1	`ssh $1 "hostname -f"`
" >> /etc/hosts 
    fi   
}

init_ceph(){
    if [ ! -e /etc/ceph/ceph.keyring ];then
      mkcephfs -a -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.keyring
    fi
}

start_ceph(){
    service ceph start
    ceph -s
}

start_osd(){
# $1 = osd number, $2 = hostname
    ssh -o StrictHostKeyChecking=no $2 "ceph-osd -i $1"
    ceph -s
}

start_mon(){
# $1=hostname
    ssh -o StrictHostKeyChecking=no $1 "ceph-mon -i $1"
    ceph -s
}

add_osd(){
    add_no=""
# 1. check osd number -> ceph osd ls
# 2. chech ceph.osd number in ceph.conf
    echo "osd add" 
    get_osd_no 
    add_no=$?
    echo "osd add: $add_no" 
    select_osd_host $add_no
}


get_osd_no(){
    add_no=""
# 1. check osd number -> ceph osd ls
# 2. chech ceph.osd number in ceph.conf

    echo "osd add" 
    for osd_no in `ceph osd ls`
    do
      if [ "$add_no" == ""  ];then
        if [ "`cat /etc/ceph/ceph.conf | grep osd.$osd_no`" == "" ]; then
          add_no=$osd_no
        fi
      fi
    done
    if [ "$add_no" == "" ]; then
      add_no=`ceph osd create`
    fi
    echo "osd add: $add_no" 
    return $add_no
}
select_osd_host(){
# $1 = osd_no
    count_i=1
    arr_lists=""
    host_lists=`cat /etc/hosts | egrep '([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $2}'`
# cat /etc/hosts | egrep '([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $1"-"$2}'
    for host in $host_lists
    do
      echo "$count_i: $host"
      arr_lists="$arr_lists $host"
      count_i=$(($count_i+1))
    done
    echo $arr_lists
    #co_i=1
    read -p "我們偵測到您的機器有以上hostname，請輸入您要設定的osd節點：" co_i
    if [ "$co_i" != "" ];then
      choice_host=$(echo $arr_lists | awk '{print $'$co_i'}')
    fi
#    echo "$choice_dev: $choice_ip"
#    echo $choice_host
    ssh-copy-id $choice_host -o StrictHostKeyChecking=no
    sync_ceph_conf_and_host $choice_host
    check_and_install_package $choice_host
    add_osd_setting $choice_host $1
    sync_ceph_conf_and_host $choice_host
    ssh -o StrictHostKeyChecking=no $choice_host "ceph-osd -i $1 --mkfs --mkkey"
    echo "starting osd..."
    start_osd $1 $choice_host
}

select_mon_host(){
    count_i=1
    arr_lists=""
    host_lists=`cat /etc/hosts | egrep '([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $1"-"$2}'`
    for host in $host_lists
    do
      echo "$count_i: $host"
      arr_lists="$arr_lists $host"
      count_i=$(($count_i+1))
    done
    echo $arr_lists
    #co_i=1
    read -p "我們偵測到您的機器有以上hostname，請輸入您要設定的mon節點：" co_i
    if [ "$co_i" != "" ];then
      choice_host=$(echo $arr_lists | awk '{print $'$co_i'}' | cut -d "-" -f2)
      choice_ip=$(echo $arr_lists | awk '{print $'$co_i'}' | cut -d "-" -f1)
    fi
    echo "choice: $choice_host"
    ssh-copy-id $choice_host -o StrictHostKeyChecking=no
    sync_ceph_conf_and_host $choice_host
    check_and_install_package $choice_host
    init_new_mon $choice_ip $choice_host
}

sync_ceph_conf_and_host(){
# $1=hstname
    scp -r /etc/ceph $1:/etc/
    scp /etc/hosts $1:/etc/
}

add_mon(){
    select_mon_host
}

init_new_mon(){
# $1=ip address, $2=hostname
    temp_path="/tmp/ceph-metafiles"
    mkdir -p $temp_path
    cp /etc/ceph/ceph.keyring $temp_path/key
    ceph mon getmap -o $temp_path/map
    scp -r $temp_path/ $2:/tmp/
    ssh -o StrictHostKeyChecking=no $2 "ceph-mon -i $2 --mkfs --monmap $temp_path/map --keyring $temp_path/key"
    add_mon_setting $2 $1
    add_mds_setting $2
    sync_ceph_conf_and_host $2
    start_mon $2
}

print_usage(){
    echo "
single mode:
deploy ceph: deploy ceph(include mon, mds)
deploy osd: add osd node
deploy mon: add mon node

=======================================================

deploy mode:
init mon <node_file>: using file to deploy mon node
init osd <node_file>: using file to deploy osd node

"
}

deploy_multi_nodes(){
# $1=file path, $2=mon, osd
# Step1: check ip and scp ssh
# Step2: setting conf
# Step3: package install
    for node in `cat $1`
    do
      checkIP $node
      if [ "$?" == "1" ]; then
        check_and_install_package $node
        if [ "$2" == "mon" ]; then
          add_mon_setting `ssh -o StrictHostKeyChecking=no $node "hostname -f"` $node
          add_mds_setting `ssh -o StrictHostKeyChecking=no $node "hostname -f"`
          edit_hosts $node `ssh -o StrictHostKeyChecking=no $node "hostname -f"`
        fi
        if [ "$2" == "osd" ]; then
          get_osd_no
          no=$?
          add_osd_setting `ssh -o StrictHostKeyChecking=no $node "hostname -f"` $no
          sync_ceph_conf_and_host `ssh -o StrictHostKeyChecking=no $node "hostname -f"`
          ssh -o StrictHostKeyChecking=no $node "ceph-osd -i $no --mkfs --mkkey"
          echo "starting osd..."
          start_osd $no `ssh -o StrictHostKeyChecking=no $node "hostname -f"`
        fi
      fi
    done

}

checkIP(){
# $1=IP address
    flag=1
    ssh-copy-id $1 -o StrictHostKeyChecking=no
    scp /etc/ceph/ceph.conf $1:/tmp/temp_$1
    pingStatus=$(ssh $1 "ls /tmp/" | grep temp_$1 )
    if [ "$pingStatus" = "" ]; then
      flag=0
    fi
    return $flag
}

sync_multi_nodes(){
    all_node_collection
    for node in `cat $exe_path/conf/all_node`
    do
      sync_ceph_conf_and_host $node
    done


}

all_node_collection(){
    collect_ip mon_node
    collect_ip mds_node
    collect_ip osd_node
    
}

collect_ip(){
# $1=file name
#    echo "" > ../conf/all_node
    for node in `cat $exe_path/conf/$1`
    do
      echo $node >> $exe_path/conf/all_node
    done
    sort $exe_path/conf/all_node | uniq > /tmp/all_node
    cp /tmp/all_node $exe_path/conf/all_node
}

check_n_install_radosgw_pkg(){
# $1=hostname

    echo "check_n_install_radosgw_pkg"
    ssh -o StrictHostKeyChecking=no $1 "apt-get -y update"
    pkg_check=`ssh -o StrictHostKeyChecking=no $1 "apt-cache search libapache2-mod-fastcgi"`
    if [ "$pkg_check" != ""  ]; then
      ssh -o StrictHostKeyChecking=no $1 "apt-get -y install ceph radosgw radosgw-agent libapache2-mod-fastcgi"
    else
      echo "can't find libapache2-mod-fastcgi, please check your source list"
      exit 0
    fi
}

setting_radosgw_conf(){
# $1=hostname
    echo "setting_radosgw_conf"

# 1. add ServerName to apache conf
# 2. edit /etc/apache2/sites-available/rgw
# 3. edit s3gw.fcgi
# 4. ensite
# 5. startup

}

edit_apache_servername(){
# $1=remote hostname
    echo "edit_apache_servername"
    r_apache_flag=`ssh -o StrictHostKeyChecking=no $1 "ls /etc/apache2/ | grep apache2.conf"`
    if [ "$r_apache_flag" != "" ] && [ "`ssh -o StrictHostKeyChecking=no $1 "cat /etc/apache2/apache2.conf | grep ServerName"`" == "" ]; then
      ssh -o StrictHostKeyChecking=no $1 "echo "ServerName	$1" >> /etc/apache2.conf"
    fi
}

create_rgw_conf(){
# $1=rgw-no, $2=portno, $3=hostname
#    cat ../conf/radosgw_node, 算出現在有幾個radosgw node
# cat -n radosgw_node | awk '{print $1}' | uniq 
    cp $exe_path/conf/rgw.conf.temp /etc/apache2/sites-available/rgw`$1`.conf
    
# sed -i 's/port-here/$2/g'/etc/apache2.conf
# sed -i 's/servername-here/$1/g'/etc/apache2.conf

}

main(){
    if [ "$1" == "deploy" ];then
      if [ "$2" == "ceph"  ];then
        ssh_key_manage
        check_and_install_package
        init_conf
        select_eth
        init_ceph
        start_ceph
        sync_multi_nodes
      fi

      if [ "$2" == "osd" ];then
	add_osd
        sync_multi_nodes
      fi

      if [ "$2" == "mon" ];then
        add_mon
        sync_multi_nodes
      fi

      if [ "$2" == "radosgw" ];then
        check_n_install_radosgw_pkg
      fi

    elif [ "$1" == "init" ]; then
      if [ "$3" != "" ] && [ "$2" == "mon" ] && [ -e $3 ] ; then
          echo "init mons.." 
          if [ -e /etc/ceph/ceph.keyring ]; then
            echo "already init mons, please use add function."
            exit 0
          fi
          check_and_install_package
          init_conf
          deploy_multi_nodes $3 $2
          sync_multi_nodes
          init_ceph
          sync_multi_nodes
      fi
      if [ "$3" != "" ] && [ "$2" == "osd" ] && [ -e $3 ] ; then
          deploy_multi_nodes $3 $2
      fi
      if [ "$1" == "add" ] && [ "$3" != "" ] && [ "$2" == "mon" ] && [ -e $3 ] ; then
          deploy_multi_nodes $3 $2
          sync_multi_nodes
          start_ceph
      fi
    else
 	print_usage
    fi
}

main $1 $2 $3
