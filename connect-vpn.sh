#!/bin/bash

CONNECTION_NAME="us.protonvpn.net.tcp"

nmcli c down $CONNECTION_NAME
sleep 25
nmcli c up $CONNECTION_NAME

currenttime=$(date +%H:%M)
if  [[ "$currenttime" < "01:30" ]] || [[ "$currenttime" > "07:30" ]]; then
    /sbin/wondershaper tun0 4000 4000
fi
