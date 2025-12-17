#!/bin/bash

# Script to automatically refresh a token by monitoring the creation time of ~/.my.cnf

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LOG_FILE="$SCRIPT_DIR/auto_refresh.log"
ENV_FILE="$SCRIPT_DIR/.auto_refresh_env"

# Source the environment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "$(date): Environment file not found at $ENV_FILE. Exiting." >> "$LOG_FILE"
    exit 1
fi

# Redirect all stdout and stderr to the log file
exec >> "$LOG_FILE" 2>&1

# --- Singleton Logic ---
MY_PID=$$
SCRIPT_NAME=$(basename "$0")

for PID in $(pgrep -f "$SCRIPT_NAME" | grep -v "$MY_PID"); do
    echo "$(date): Found and killing old instance of $SCRIPT_NAME with PID: $PID"
    kill "$PID"
done

echo "$(date): Starting $SCRIPT_NAME with PID: $MY_PID"

# --- Main Monitoring Loop ---
while true; do
    CONFIG_FILE="$HOME/.my.cnf"
    REFRESH_SCRIPT="$HOME/workspace/aws/refresh_token.sh"

    while [ ! -f "$CONFIG_FILE" ]; do
        echo "$(date): Configuration file not found: $CONFIG_FILE. Waiting..."
        sleep 60
    done

    last_creation_time=$(stat -f %B "$CONFIG_FILE")
    creation_date=$(date -r "$last_creation_time")

    refresh_time=$((last_creation_time + 14 * 60))
    refresh_date=$(date -r "$refresh_time")

    echo "$(date): Token created at: $creation_date. Next refresh scheduled for: $refresh_date."

    current_time=$(date +%s)
    sleep_duration=$((refresh_time - current_time))

    if [ "$sleep_duration" -gt 0 ]; then
        echo "$(date): Sleeping for $sleep_duration seconds."
        sleep "$sleep_duration"
    else
        echo "$(date): Token is older than 14 minutes. Refreshing immediately."
    fi

    echo "$(date): Executing refresh script: $REFRESH_SCRIPT"
    if [ -x "$REFRESH_SCRIPT" ]; then
        /bin/bash "$REFRESH_SCRIPT"
    else
        echo "$(date): Error: Refresh script not found or is not executable at $REFRESH_SCRIPT."
        sleep 60
        continue
    fi

    echo "$(date): Waiting for token file to be updated..."
    while [ "$(stat -f %B "$CONFIG_FILE")" -eq "$last_creation_time" ]; do
        sleep 5
    done

    echo "$(date): Token file has been successfully updated. Restarting monitoring cycle."
    echo "-----------------------------------------------------"
done
