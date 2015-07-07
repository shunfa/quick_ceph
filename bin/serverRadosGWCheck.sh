#!/bin/bash
Work_Path=`dirname "$0"`
cd $Work_Path
. ../conf/callBackConf.sh 


result_out=""

function check_list(){
    CHANGE_FLAG=0
    for node in $(cat ../conf/radosgw_node)
    do
	radosgwPrecessFlag=$(ssh -o StrictHostKeyChecking=no $node "ls /run/ceph/ | grep radosgw")
	result=$(curl -I $node | grep HTTP | grep 200)
	inOnlineList=$(cat ../infos/RadosGWOnlineNode | grep $node)
	if [ "$result" != "" ]; then
	    if [ "$radosgwPrecessFlag" != "" ]; then
		if [ "$inOnlineList" = "" ]; then
		    echo $node >> ../infos/RadosGWOnlineNode
		    CHANGE_FLAG=1
		fi
	    fi
	else
	    if [ "$inOnlineList" != "" ]; then
		sed -i 's/'$node'//g' ../infos/RadosGWOnlineNode
		sed -i '/^$/d' ../infos/RadosGWOnlineNode
		echo "$node remove from online list."
		CHANGE_FLAG=1
	    fi	
	fi
    done

    cat ../infos/RadosGWOnlineNode | sort | uniq > /tmp/nodeOnline.tmp
    cp /tmp/nodeOnline.tmp ../infos/RadosGWOnlineNode

    if [ $CHANGE_FLAG = 1 ]; then
	echo "call api"
	api_server_callback
    fi
}

function api_server_callback(){
    pingFlag=$(ping -c 3 $CALLBACKIP | grep received | awk '{print $4}')
    if [ $pingFlag = 0 ]; then
	echo $CALLBACKIP unreachable!
	exit 0;
    fi
    print_list_json
    curl -H "Content-Type: application/json" -d "$result_out" http://$CALLBACKIP:$CALLBACKPORT/?UpdateRadosgwEndpointList
}

function init_api_server_sync(){
    SYNC_IP=$1
    PORT=$2
#echo "init_api_server_sync"
    if [ "$PORT" = "" ]; then
	echo "Please Typing API Server IP and Port"
	exit 0
    else
#	echo "process...$SYNC_IP"
	echo "#!/bin/bash                                                                                                   
CALLBACKIP=$SYNC_IP
CALLBACKPORT=$PORT" > $(pwd)/conf/callBackConf.sh
	print_list_json
    fi
}

function print_list_json(){
    result_out="{\"nodelist\":"
    count=0
    for node in $(cat ../infos/RadosGWOnlineNode)
    do
	if [ $count = 0 ]; then
	    result_out=$result_out[{\"ipaddress\":\"$node\"}
	else
	    result_out=$result_out,{\"ipaddress\":\"$node\"}
	fi
	count=$((count+1))
    done
    result_out=$result_out"]}"
    echo $result_out
}

function print_usage(){
    echo "usage: 
  ./serverCheck.sh checklist
  ./serverCheck.sh livenode
  ./serverCheck.sh api_server_init <init_ip> <init_port>"
}

function main(){
    OPT=$1

    if [ "$OPT" = "" ]; then
	print_usage
    fi

    if [ "$OPT" = "checklist" ]; then
	check_list
    fi

    if [ "$OPT" = "api_server_init" ]; then
	init_api_server_sync $2 $3
    fi

    if [ "$OPT" = "livenode" ]; then
	print_list_json	
    fi
}

main $1 $2 $3
