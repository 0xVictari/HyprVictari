#!/bin/bash

STATE_FILE="/tmp/gaming-mode-state"
CONFIG_FILE="$HOME/.config/hypr/gaming-apps.conf"

# Load gaming apps
if [ -f "$CONFIG_FILE" ]; then
    mapfile -t GAMING_APPS < <(grep -v '^#' "$CONFIG_FILE" | grep -v '^[[:space:]]*$')
else
    GAMING_APPS=("steam" "retroarch" "melonds" "duckstation" "gzdoom" "woof" "openmw")
fi

PATTERN=$(IFS='|'; echo "${GAMING_APPS[*]}")

if [ -f "$STATE_FILE" ]; then
    # Check what's running
    RUNNING=$(pgrep -i "($PATTERN)" | head -1)
    if [ -n "$RUNNING" ]; then
        APP_NAME=$(ps -p $RUNNING -o comm= | head -1)
        echo "{\"text\": \"🎮\", \"class\": \"active\", \"tooltip\": \"Gaming Mode: ON\\nRunning: $APP_NAME\"}"
    else
        echo "{\"text\": \"🎮\", \"class\": \"active\", \"tooltip\": \"Gaming Mode: ON\\nWaiting for games...\"}"
    fi
else
    echo "{\"text\": \"󰺶 \", \"class\": \"inactive\", \"tooltip\": \"Gaming Mode: OFF\\nClick to enable\"}"
fi
