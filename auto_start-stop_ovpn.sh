#!/bin/bash

IF="tun0"                               # Interface used for ping
ping1_target="8.8.8.8"                  # IP no. 1 used for ping
ping2_target="82.165.229.31"            # IP no. 2 used for ping
ping_interval="5"                       # waiting time in-between two pings
switchback_interval="3600"              # waiting time for interface to recover before probing again
start_grace="10"                        # waiting time to allow for tunnel restart
logfile="/dev/null"                     # logfile for debug
gwsel_lockfile="/tmp/gwsel_lockfile"    # lockfile to allow for low bandwidth settings 

openvpn_stop-cmd () {                   # command used disabling tunnel
    #service openvpn stop                # ubuntu
    /etc/init.d/openvpn stop            # debian
    #killall openvpn                     # hardcore
}

openvpn_start-cmd () {                   # command used enabling tunnel
    #service openvpn start                # ubuntu
    /etc/init.d/openvpn start            # debian
    #openvpn /etc/openvpn/*.conf &        # hardcore
}

ping1 () {
    echo "$(date): ping -q -c 3 -i ${ping_interval} ${ping1_target} -I $IF" &>> $logfile
    ping -q -c 3 -i ${ping_interval} ${ping1_target} -I $IF &>> $logfile
    ping1_ExitCode=$?
    echo "$(date): Exit Status: ${ping1_ExitCode}" &>> $logfile
}

ping2 () {
    echo "$(date): ping -q -c 3 -i ${ping_interval} ${ping2_target} -I $IF" &>> $logfile
    ping -q -c 3 -i ${ping_interval} ${ping2_target} -I $IF &>> $logfile
    ping2_ExitCode=$?
    echo "$(date): Exit Status: ${ping2_ExitCode}" &>> $logfile
}


while true
do
    # wait for interface build-up, if interface not present
    if [ ! -h "/sys/class/net/$IF" ]; then
        echo "$(date): Interface $IF not detected. Waiting ${start_grace} seconds." &>> $logfile
        sleep ${start_grace}
    fi

    # perform ping
    ping1
    ping2

    # check if ping successful
    if ([[ ${ping1_ExitCode} -eq 0 ]] || [[ ${ping2_ExitCode} -eq 0 ]]); then
        sleep ${ping_interval}
    else
        logger -t "$0" ${ping1_target} and ${ping2_target} not reached via interface $IF.
        echo "$(date): ${ping1_target} and ${ping2_target} not reached via interface $IF." &>> $logfile
        touch ${gwsel_lockfile} &>> $logfile

        if [ -h "/sys/class/net/$IF" ]; then
            logger -t "$0" Stopping interface $IF.
            echo "$(date): Stopping interface $IF." &>> $logfile
            openvpn_stop-cmd &>> $logfile
        fi

        sleep ${switchback_interval}
        rm -f ${gwsel_lockfile} &>> $logfile

        if [ ! -h "/sys/class/net/$IF" ]; then
            logger -t "$0" Restoring interface $IF to probe for recovery.
            echo "$(date): Restoring interface $IF to probe for recovery." &>> $logfile
            openvpn_start-cmd &>> $logfile
        fi
    fi
done
