#!/bin/bash

# IPTABLES port destination IP Manager/Switch (for NAT table)
# Works with root rights
# github.com/reshetylo/natipmanager by Yurii Reshetylo

TIMEOUT=5
CHECK_DELAY=8
LOCK_FILE=~/natipmanagemer.lock
IP_INPUT_FILE=$1
LIST=""
declare -A STATUS_MAP
DELIM="========="
IPTABLES_BIN="/sbin/iptables"

if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

if [ -f $LOCK_FILE ]; then # check for lock file
    echo "Lock file ${LOCK_FILE} exists. Check if another copy is running or remove file and start script again."
    exit 302
fi

if [ ! $IP_INPUT_FILE ]; then # check for input file. CSV list
    echo "Input file not set."
    exit 403
fi

if [ ! -f $IP_INPUT_FILE ]; then # check if provided file exists
    echo "Input file ${IP_INPUT_FILE} does not exist."
    exit 404
fi

function clean_data {
    rm ${LOCK_FILE}
    exit
}

function decho {
    echo -e `date +"%F %H:%m:%S"` $1
}

function read_list {
    IFS=$'\r\n'
    GLOBIGNORE='*'
    LIST=$(<${IP_INPUT_FILE})
    decho "IP list updated."
}

function check_connection {
    if [ $2 == "PR" ]; then next="SE"; chk_host=$3; chk_port=$4; fi
    if [ $2 == "SE" ]; then next="FO"; chk_host=$5; chk_port=$6; fi
    if [ $2 == "FO" ]; then next="PR"; chk_host=$7; chk_port=$8; fi

    nc -z -w$TIMEOUT $chk_host $chk_port
    if [ $? == 0 ]; then connection='ok'; else connection='fail'; fi

    if [ $connection == 'fail' ]; then
        decho "Port $1: $2 Connection fail ($chk_host:$chk_port)"
        check_connection $1 $next $3 $4 $5 $6 $7 $8
    else
        decho "Port $1: $2 Connection OK"
        if [ ! "${STATUS_MAP[$1]}" == "$2" ]; then
            change_ip $1 $chk_host:$chk_port
            STATUS_MAP[$1]=$2
            decho "Port $1: SWITCHED to $2 ($chk_host:$chk_port)"
        fi
    fi
}

function change_ip {
    IPTABLES_STATUS=`$IPTABLES_BIN -t nat -S | grep "\-A PREROUTING -p tcp -m tcp --dport $1 -j DNAT --to-destination"`
    CURRENT_DEST=`echo ${IPTABLES_STATUS} | cut -d" " -f 12`

    if [ "$IPTABLES_STATUS" ]; then
        DELETE_COMMAND="${IPTABLES_BIN} -t nat "`echo ${IPTABLES_STATUS} | sed 's/-A/-D/g'`
        decho "RUN: $DELETE_COMMAND"
        eval $DELETE_COMMAND # real action happens here
    fi
    CREATE_COMMAND="${IPTABLES_BIN} -t nat -A PREROUTING -p tcp -m tcp --dport $1 -j DNAT --to-destination $2"
    decho "RUN: $CREATE_COMMAND"
    eval $CREATE_COMMAND # real action happens here too
    decho "Record:\t${IPTABLES_STATUS}\nUpdated with:\t${CREATE_COMMAND}\n${DELIM}"
}

function process_line { # this function process every line from csv file and initiates connection checker
    SRC_PORT=`echo $1 | cut -d"," -f1`
    PRIMARY=`echo $1 | cut -d"," -f2`
    PR_HOST=`echo $PRIMARY | cut -d":" -f 1`
    PR_PORT=`echo $PRIMARY | cut -d":" -f 2`
    SECONDARY=`echo $1 | cut -d"," -f3`
    SE_HOST=`echo $SECONDARY | cut -d":" -f 1`
    SE_PORT=`echo $SECONDARY | cut -d":" -f 2`
    FAILOVER=`echo $1 | cut -d"," -f4`
    FO_HOST=`echo $FAILOVER | cut -d":" -f 1`
    FO_PORT=`echo $FAILOVER | cut -d":" -f 2`
    if [ ! "${STARTED}" ]; then decho "SOURCE PORT: ${SRC_PORT}\nPrimary: ${PR_HOST} port ${PR_PORT}\nSecondary: ${SE_HOST} port ${SE_PORT}\nFailover: ${FO_HOST} port ${FO_PORT}\n${DELIM}"; fi

    check_connection ${SRC_PORT} PR ${PR_HOST} ${PR_PORT} ${SE_HOST} ${SE_PORT} ${FO_HOST} ${FO_PORT}
}

# catch signals and clean after start
trap clean_data SIGHUP SIGINT SIGTERM

decho "Starting IPTABLES port destination manager/switch"
date +"%s" > ${LOCK_FILE}
read_list

while [ -f ${LOCK_FILE} ]; do
    for item in ${LIST[@]}; do
        process_line $item
    done
    STARTED="1"
    sleep ${CHECK_DELAY}
done
clean_data
# THE END