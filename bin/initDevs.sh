#!/bin/bash

check_pkg(){
    echo "check packages..."
# pkg: dialog, madam
    apt-get install -y mdadm dialog
}

dialog_sel_devs(){
    devices=$(ls /dev/ | grep sd)
    dev_list=""
    for devs in $devices
    do
      dev_list=$dev_list" "$devs" "$devs" "$devs
    done

    sel_dev=`dialog --stdout --checklist "Select Devices" 20 100 10 $dev_list`
    if [ $? -eq 0 ]; then
      echo $sel_dev | sed 's/\"//g' > /tmp/sel
      confirm_to_format
    fi
#    ls /dev/ | grep sd
}

confirm_to_format(){
    echo "confirm to format"
    read answer "aaa"
#    read "Are you sure to foramt these devices?" answer
    if [ "$answer" = "yes" ]; then
      delete_soft_raid
      create_soft_raid
    fi
}

delete_soft_raid(){
    ls_md=`ls /dev/ | grep md`
    if [ "$ls_md" != "" ]; then
        echo "exe: mdadm --stop /dev/md*"
    fi 

}

create_soft_raid(){
# raid 0, file path=/tmp/sel
    dev_count=0
    devices=`cat /tmp/sel`
    dev_list=""
    for devs in $devices
    do
      dev_list=$dev_list" "$devs
      dev_count=$(($dev_count+1))
    done
    echo "exe: mdadm -C /dev/md0 --level=raid0 --raid-devices=$dev_count $dev_list"
    cd /dev/
    echo "mdadm -C /dev/md0 --level=raid0 --raid-devices=$dev_count $dev_list"
}

main(){
    dialog_sel_devs
#    delete_soft_raid
}

main
