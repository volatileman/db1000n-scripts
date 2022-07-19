#!/bin/bash

CONNECTION_NAME="us.protonvpn.net.tcp"

nmcli c down $CONNECTION_NAME
sleep 25
nmcli c up $CONNECTION_NAME

