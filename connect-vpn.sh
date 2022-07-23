#!/bin/bash

CONNECTION_NAME="us.protonvpn.net.tcp"
MAX_ATTEMPTS=3
ATEMPT=1

nmcli c down $CONNECTION_NAME

while [ $ATEMPT -le $MAX_ATTEMPTS ]
do
    sleep 20
    
    if nmcli c up $CONNECTION_NAME; then
        break
    fi
    
    ((ATEMPT++))
done;
