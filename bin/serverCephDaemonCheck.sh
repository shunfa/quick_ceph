#!/bin/bash
Work_Path=`dirname "$0"`
cd $Work_Path


function checkMON(){
    echo "check mon daemon"
    CHANGE_FLAG=0
    for node in $(cat ../conf/mon_node)
    do
        monPrecessFlag=$(ssh -o StrictHostKeyChecking=no $node "ls /run/ceph/ | grep mon")
	inOnlineList=$(cat ../infos/MonOnlineNode | grep $node)
	if [ "$monPrecessFlag" != "" ]; then
            if [ "$inOnlineList" = "" ]; then
	        echo $node >> ../infos/MonOnlineNode
	        CHANGE_FLAG=1
	    fi
            echo "$node is online."
	else
	    if [ "$inOnlineList" != "" ]; then
		sed -i 's/'$node'//g' ../infos/MonOnlineNode
		sed -i '/^$/d' ../infos/MonOnlineNode
		echo "$node remove from online list."
		CHANGE_FLAG=1
	    fi
            echo "$node is offline."
	fi
    done
}

function checkMDS(){
    echo "check mds daemon"
    CHANGE_FLAG=0
    for node in $(cat ../conf/mds_node)
    do
        monPrecessFlag=$(ssh -o StrictHostKeyChecking=no $node "ls /run/ceph/ | grep mds")
	inOnlineList=$(cat ../infos/MdsOnlineNode | grep $node)
	if [ "$monPrecessFlag" != "" ]; then
            if [ "$inOnlineList" = "" ]; then
	        echo $node >> ../infos/MdsOnlineNode
	        CHANGE_FLAG=1
	    fi
            echo "$node is online."
	else
	    if [ "$inOnlineList" != "" ]; then
		sed -i 's/'$node'//g' ../infos/MdsOnlineNode
		sed -i '/^$/d' ../infos/MdsOnlineNode
		echo "$node remove from online list."
		CHANGE_FLAG=1
	    fi	
            echo "$node is offline."
	fi
    done
}


function checkOSD(){
    echo "check osd daemon"
    CHANGE_FLAG=0
    for node in $(cat ../conf/osd_node)
    do
        monPrecessFlag=$(ssh -o StrictHostKeyChecking=no $node "ls /run/ceph/ | grep osd")
	inOnlineList=$(cat ../infos/OsdOnlineNode | grep $node)
	if [ "$monPrecessFlag" != "" ]; then
            if [ "$inOnlineList" = "" ]; then
	        echo $node >> ../infos/OsdOnlineNode
	        CHANGE_FLAG=1
	    fi
            echo "$node is online."
	else
	    if [ "$inOnlineList" != "" ]; then
		sed -i 's/'$node'//g' ../infos/OsdOnlineNode
		sed -i '/^$/d' ../infos/OsdOnlineNode
		echo "$node remove from online list."
		CHANGE_FLAG=1
	    fi	
            echo "$node is offline."
	fi
    done
}

function showStatus(){
#    result_out="{\"nodelist\":"
    resultMONList=""
    resultMDSList=""
    resultOSDList=""
    resultRADOSGWList=""
    count=0
    for node in $(cat ../infos/RadosGWOnlineNode)
    do
        if [ $count = 0 ]; then
            resultRADOSGWList=\"$node\"
        else
            resultRADOSGWList=$resultRADOSGWList","\"$node\"
        fi
        count=$((count+1))
    done

    count=0
    for node in $(cat ../infos/MonOnlineNode)
    do
        if [ $count = 0 ]; then
            resultMONList=\"$node\"
        else
            resultMONList=$resultMONList","\"$node\"
        fi
        count=$((count+1))
    done

    count=0
    for node in $(cat ../infos/MdsOnlineNode)
    do
        if [ $count = 0 ]; then
            resultMDSList=\"$node\"
        else
            resultMDSList=$resultMDSList","\"$node\"
        fi
        count=$((count+1))
    done

    count=0
    for node in $(cat ../infos/OsdOnlineNode)
    do
        if [ $count = 0 ]; then
            resultOSDList=\"$node\"
        else
            resultOSDList=$resultOSDList","\"$node\"
        fi
        count=$((count+1))
    done
    
#    echo "radosgw_list:"$resultRADOSGWList
#    echo "mon_list:"$resultMONList
#    echo "mds_list:"$resultMDSList
#    echo "osd_list:"$resultOSDList

    echo \{\"radosgw_list\":[$resultRADOSGWList],\"mon_list\":[$resultMONList],\"mds_list\":[$resultMDSList], \"osd_list\":[$resultOSDList]}
}

function main(){
    echo "main function"
    checkMON
    checkMDS
    checkOSD
    showStatus
}


function print_usage(){
    echo "usage: 
  ./server checklist
  ./server livenode"
}

function main(){
    OPT=$1

    if [ "$OPT" = "" ]; then
        print_usage
    fi

    if [ "$OPT" = "checklist" ]; then
	checkMON
    	checkMDS
    	checkOSD
	showStatus
    fi

    if [ "$OPT" = "livenode" ]; then
	showStatus
    fi
}


main $1
