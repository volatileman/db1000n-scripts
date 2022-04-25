#!/bin/bash

# This script automatically downloads and starts db1000n then monitors its effectivity.
# If needed it restarts the connection and db1000n.
# It also checks for a new release of db1000n every 3 hours and if available downloads it and run it
# Warning! It depends on the output of db1000n so multiple workers are not supported (-scale option)

# Run this script with three params (e.g. './activity-check_new.sh 1200 12 my-vpn') or without any
# 1200 is the interval in seconds for expected traffic to be generated
# 12 is the expected traffic in mega bytes to be generated regard to stats
# Actual restart will happen only if expected traffic was not generated during the specified interval
# 'my-vpn' is the connection name in Network Manager

downloadAttacker() {
  echo ========================================================================
  echo $(date): Downloading attacker release: ${LATEST_TAG}

  wget -c "https://github.com/Arriven/db1000n/releases/download/${LATEST_TAG}/db1000n_linux_amd64.tar.gz" -O - | tar -xz db1000n
  LOCAL_VERSION=$LATEST_RELEASE_VERSION

  echo $(date): Downloading completed
  echo ========================================================================
}

killPreviousAttacker() {
  echo ========================================================================
  echo "$(date): Summary generated: ${SUMMARY_GENERATED}MB"

  if [ ! -z "${ATTACKER_PID}" ]; then
    echo "$(date): Killing previous app. PID: ${ATTACKER_PID}"
    kill $ATTACKER_PID
  fi
}

getAttackerVersion() {
  echo $(./db1000n -version | grep -Po "Version: .*]\[" | grep -Po "\d*" | tr -d '\n')
}

isNewerAttackerAvailable() {
  LATEST_TAG=$(curl -s https://api.github.com/repos/Arriven/db1000n/releases | jq -r '.[0].tag_name')
  LATEST_RELEASE_VERSION=$(echo $LATEST_TAG | grep -Po "\d*" | tr -d '\n')

  echo "$(date): Checking for a new attacker"
  echo "Latest relese: ${LATEST_TAG}"

  if [ -s "./db1000n" ]; then
    LOCAL_VERSION=$(getAttackerVersion)

    if [ $LATEST_RELEASE_VERSION -gt $LOCAL_VERSION ]; then
      echo "Local attacker: $LOCAL_VERSION"
      echo "Found newer attacker: $LATEST_RELEASE_VERSION"
      return 0
    fi
  else
    echo "No local attacker found"
    return 0
  fi

  return 1
}

isVPNActive() {
  if [ -z "${CONNECTION_NAME}" ]; then
    return 0
  else
    if nmcli con show --active | grep -q $CONNECTION_NAME; then return 0; else return 1; fi
  fi
}

reconnectVPN() {
  if [ ! -z "${CONNECTION_NAME}" ]; then
    if isVPNActive; then
      nmcli c down $CONNECTION_NAME
      sleep 5
      nmcli c up $CONNECTION_NAME
    else
      nmcli c up $CONNECTION_NAME
    fi
  fi
}

startAttacker() {
  reconnectVPN

  echo ========================================================================
  echo "$(date): Starting attacker: ${LOCAL_VERSION}"

  ./db1000n &
  ATTACKER_PID=$!

  if [ -z "${ATTACKER_PID}" ]; then
    echo "Can not start attacker!"
    exit
  fi
}

echo "+++ Started Auto-Attacker script +++"

# TODO: check for all needed tools

RELEASE_CHECK_INTERVAL=10800 # Each 3 hours
LAST_RELEASE_CHECK_TIME=$(date +%s)

CONNECTION_NAME=$1

echo "Connection to use: ${CONNECTION_NAME:-"---"}"
echo "Initial launch..."

if isNewerAttackerAvailable; then
  downloadAttacker
fi

LOCAL_VERSION=$(getAttackerVersion)

startAttacker

echo "Starting loop..."
while true; do
  isVPNActive || reconnectVPN

  if [ "$(expr $(date +%s) - $LAST_RELEASE_CHECK_TIME)" -gt $RELEASE_CHECK_INTERVAL ]; then
    LAST_RELEASE_CHECK_TIME=$(date +%s)

    reconnectVPN

    if isNewerAttackerAvailable; then
      killPreviousAttacker
      downloadAttacker
      startAttacker
    fi
  fi

  sleep 5
done
