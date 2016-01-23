#!/bin/bash
gwsel_lockfile="/tmp/gwsel_lockfile"  # lockfile to allow for low bandwidth settings 

if [ -z "$1" ]; then
        echo
        echo "usage: $0 <network-interface> <update_interval [sec]> <total BW up [Mbit/sec]> <total BW down [Mbit/sec]>"
        echo
        echo "e.g. $0 eth0 60 10 10"
        echo
        exit
fi

while true
do
    if [ ! -e ${gwsel_lockfile} ]; then    # lockfile not present
        # Bandwidth currently used (time averaged)
        R1=$(cat "/sys/class/net/$1/statistics/rx_bytes")
        T1=$(cat "/sys/class/net/$1/statistics/tx_bytes")
        sleep "$2"
        R2=$(cat "/sys/class/net/$1/statistics/rx_bytes")
        T2=$(cat "/sys/class/net/$1/statistics/tx_bytes")
        TkbitPS=$(echo "scale=0; ($T2 - $T1) / 1024 * 8 / $2" | bc -l)
        RkbitPS=$(echo "scale=0; ($R2 - $R1) / 1024 * 8 / $2" | bc -l)
#        echo "BW used      -- up $1: $TkbitPS kBit/s; down $1: $RkbitPS kBit/s"

        # Remaining bandwidth available; cut-off negative values
        Tavail_kbitPS=$(echo "scale=0; if (($3 * 1024 - $TkbitPS) >0) ($3 * 1024 - $TkbitPS) else 0" | bc -l)
        Ravail_kbitPS=$(echo "scale=0; if (($4 * 1024 - $RkbitPS) >0) ($4 * 1024 - $RkbitPS) else 0" | bc -l)
#        echo "BW available -- up $1: $Tavail_kbitPS kBit/s; down $1: $Ravail_kbitPS kBit/s"
    else                                     # lockfile present
        Tavail_kbitPS=0
        Ravail_kbitPS=0
        sleep "$2"
    fi

    for bat in /sys/class/net/bat*; do
              iface=${bat##*/}
              batctl -m $iface gw_mode server "${Ravail_kbitPS}kbit/${Tavail_kbitPS}kbit" 
    done
done
