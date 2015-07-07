#!/bin/bash
#echo "deploy funs"
#set -e
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`
#deceph_path=`dirname $bin`

#exe_path="/root/deceph"
exe_path=`dirname $bin`

select_node(){
# $1=mon, osd, radosgw
    echo "fun: select_node"
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
    read -p "我們偵測到您的機器有以上節點名稱，請輸入您要設定的`$1`節點：" co_i
    if [ "$co_i" != "" ];then
      choice_host=$(echo $arr_lists | awk '{print $'$co_i'}' | cut -d "-" -f2)
      choice_ip=$(echo $arr_lists | awk '{print $'$co_i'}' | cut -d "-" -f1)
    fi
    echo "choice: $choice_host"
    echo "$choice_host" > /tmp/res
}

sshkey_manager(){
    echo "fun: sshkey_manager"
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

pkg_radosgw_check_n_install(){
# $1=hostname
    echo "pkg_radosgw_check_n_install"
    ssh -o StrictHostKeyChecking=no $1 "apt-get -y update"
    pkg_check=`ssh -o StrictHostKeyChecking=no $1 "apt-cache search libapache2-mod-fastcgi"`
    if [ "$pkg_check" != ""  ]; then
      ssh -o StrictHostKeyChecking=no $1 "apt-get -y install apache2 ceph radosgw radosgw-agent libapache2-mod-fastcgi"
    else
      echo "can't find libapache2-mod-fastcgi, please check your source list"
      exit 0
    fi
}

edit_apache_conf(){
# $1=hostname
    echo "edit_apache_conf"
    r_apache_flag=`ssh -o StrictHostKeyChecking=no $1 "ls /etc/apache2/ | grep apache2.conf"`
    if [ "$r_apache_flag" != "" ] && [ "`ssh -o StrictHostKeyChecking=no $1 "cat /etc/apache2/apache2.conf | grep ServerName"`" == "" ]; then
      ssh -o StrictHostKeyChecking=no $1 "echo "ServerName      $1" >> /etc/apache2/apache2.conf"
    fi
}

create_rgw_conf(){
# $1=hostname, $2=radosgw_no, $3=port_no
    unset i
    i=$2
    port_no=$((8080+i))
    echo "PN: $port_no"
    echo "create_rgw_conf"
    rm -rf /tmp/rgw-*
    mkdir -p /tmp/rgw-$2/
#    cp ../conf/rgw.conf.temp /tmp/rgw-$2/rgw"$2".conf
#    cp ../conf/rgw.conf.temp /tmp/rgw-$2/rgw"$2".conf
     cp $exe_path/conf/rgw.conf.temp /tmp/rgw-$2/rgw"$2".conf
     cp $exe_path/conf/s3gw.fcgi /tmp/rgw-$2/s3gw.fcgi
    if [ "$2" == "0" ]; then
        mv /tmp/rgw-$2/rgw"$2".conf /tmp/rgw-$2/rgw.conf
        port_no="80"
        sed -i 's/port-here/'$port_no'/g' /tmp/rgw-$2/rgw.conf
        sed -i 's/servername-here/'$1'/g' /tmp/rgw-$2/rgw"$2".conf
    else 
        sed -i '1,3d' /tmp/rgw-$2/rgw$2.conf
    fi
    
# edit confs...
   sed -i 's/port-here/'$port_no'/g' /tmp/rgw-$2/rgw"$2".conf
   sed -i 's/servername-here/'$1'/g' /tmp/rgw-$2/rgw"$2".conf
   _add_radosgw_setting $1 "radosgw.decephgw" $port_no
#  sed -i '1i xxxxx' /tmp/rgw-$2/rgw"$2".conf
   if [ "$port_no" != "80" ]; then
     sed -i '1i Listen '$port_no'' /tmp/rgw-$2/rgw"$2".conf
   fi
}

sync_ceph_conf_and_host(){
# $1=hstname
    scp -r /etc/ceph $1:/etc/
    scp /etc/hosts $1:/etc/
}

sync_rados_conf(){
# $1=hostname
    echo "sync_rados_conf"
    sync_ceph_conf_and_host $1
# /etc/ceph, /etc/hosts, rgw conf
}

write_service_node(){
# $1=hostname, 
    echo "write_service_node"
#    _add_radosgw_setting $1 "radosgw.decephgw"
}

_add_radosgw_setting(){
# $1 = hostname, $2 = key name, ex: radosgw.gateway, $3=port_no
    echo "[client.$2.$1.$3]
\\\host = $1
\\\keyring = /etc/ceph/keyring.$2
\\\rgw socket path = /tmp/radosgw.sock
\\\log file = /var/log/ceph/radosgw.log
\\\
" > /tmp/rgw_tmp
    if [ ! -e "/etc/ceph/keyring.$2" ]; then 
      _init_radosgw $2
    fi
    _write_setting radosgw /tmp/rgw_tmp $1 $3
}


_write_setting(){
# $1=service name(e.g. mon, mds, osd, radosgw), $2=message, $3=hostname, $4=port_no 
    echo "Write setting to conf file..."
    editLineNo=$(cat -n /etc/ceph/ceph.conf | grep "$1-section-end" | awk '{print $1}')
    editLineNo=$((editLineNo-1))
    if [ "$4" == "80" ] || [ "$4" == "" ]; then
      exec < $2
      sed -i ''$editLineNo'a\\' /etc/ceph/ceph.conf
      editLineNo=$((editLineNo+1))
      while read line
      do
        sed -i ''$editLineNo'a'"$line"'' /etc/ceph/ceph.conf
        editLineNo=$((editLineNo+1))
      done
    fi
    if [ "$4" != "" ]; then
        echo $3:$4 >> $exe_path/conf/$1_node
    else
        echo $3 >> $exe_path/conf/$1_node
    fi
}

get_radosgw_no(){
#$1 = hostname
    rgw_no=`ssh -o StrictHostKeyChecking=no $1 "ls /etc/apache2/sites-available/ | grep rgw | wc -l"`
    echo "$rgw_no" > /tmp/res
}

mod_setup(){
# $1=hostname
    echo "mod setup"
    ssh -o StrictHostKeyChecking=no $1 "a2enmod rewrite"
    ssh -o StrictHostKeyChecking=no $1 "a2enmod fastcgi"
    ssh -o StrictHostKeyChecking=no $1 "service apache2 restart"
}

_init_radosgw(){
# $1=radosgw_name
    cd /etc/ceph/
    ceph-authtool -C -n client.$1 --gen-key /etc/ceph/keyring.$1
    ceph-authtool -n client.$1 --cap mon 'allow rw' --cap osd 'allow rwx' /etc/ceph/keyring.$1
    ceph auth add client.$1 --in-file=keyring.$1
}

deploy_confs(){
# $1=hostname, $2=rgw_no
    scp /tmp/rgw-$2/rgw*.conf $1:/etc/apache2/sites-available/
    scp /tmp/rgw-$2/s3gw.fcgi $1:/var/www/
    ssh -o StrictHostKeyChecking=no $1 "chmod a+x /var/www/s3gw.fcgi"
    ssh -o StrictHostKeyChecking=no $1 "a2ensite rgw*"
    ssh -o StrictHostKeyChecking=no $1 "a2dissite *default"
    ssh -o StrictHostKeyChecking=no $1 "service apache2 reload"
}
start_up(){
# $1=hostname
    ssh -o StrictHostKeyChecking=no $1 "service apache2 restart"
    ssh -o StrictHostKeyChecking=no $1 "/etc/init.d/radosgw start"
}


sync_multi_nodes(){
    _all_node_collection
    for node in `cat $exe_path/conf/all_node`
    do
      sync_ceph_conf_and_host $node
    done
}

_all_node_collection(){
    _collect_ip mon_node
    _collect_ip mds_node
    _collect_ip osd_node
}

_collect_ip(){
# $1=file name
#    echo "" > ../conf/all_node
    for node in `cat $exe_path/conf/$1`
    do
      echo $node >> $exe_path/conf/all_node
    done
    sort $exe_path/conf/all_node | uniq > /tmp/all_node
    cp /tmp/all_node $exe_path/conf/all_node
}
