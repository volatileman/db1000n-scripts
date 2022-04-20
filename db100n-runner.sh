#!/bin/bash

downloadAttaker() {
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
  echo "$(date): Reconnecting to the VPN: $1"

  nmcli c down $1
  sleep 3
  nmcli c up $1

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

CONNECTION_NAME=$1
TIME_OUT_SEC=$2
MIN_TRAFFIC="${3:-8}"
SUMMARY_GENERATED=0
TRAFFIC_STATS_COUNT=0

echo "Connection to use: ${CONNECTION_NAME}"
echo "Timeout in seconds: $TIME_OUT_SEC"
echo "Minimal traffic before attacker reset: ${MIN_TRAFFIC}MB"
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

    SUMMARY_GENERATED=$(echo $TOTAL + $SUMMARY_GENERATED | bc)

    if (($(echo "$TOTAL < $MIN_TRAFFIC" | bc -l))) && [ "$(expr $(date +%s) - $PROCESS_STARTUP_TIME)" -gt $TIME_OUT_SEC ]; then
      killPreviousAttacker
      startAttacker $CONNECTION_NAME
    fi
  fi

  if [ "$(expr $(date +%s) - $LAST_RELEASE_CHECK_TIME)" -gt 10800 ]; then # Each 3 hours check for a new release
    LAST_RELEASE_CHECK_TIME=$(date +%s)

    if isNewerAttackerAvailable; then
      killPreviousAttacker
      downloadAttaker
      startAttacker $2
    fi
  fi

  sleep 5
done
