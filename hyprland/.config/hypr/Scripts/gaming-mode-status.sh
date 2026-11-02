#!/bin/bash

STATE_FILE="/tmp/gaming-mode-state"

source "$(dirname "$0")/gaming-mode-detect.sh"

if [ -f "$STATE_FILE" ]; then
    if APP_NAME=$(find_game); then
        echo "{\"text\": \"🎮\", \"class\": \"active\", \"tooltip\": \"Gaming Mode: ON\\nRunning: $APP_NAME\"}"
    else
        echo "{\"text\": \"🎮\", \"class\": \"active\", \"tooltip\": \"Gaming Mode: ON\\nWaiting for games...\"}"
    fi
else
    echo "{\"text\": \"󰺶 \", \"class\": \"inactive\", \"tooltip\": \"Gaming Mode: OFF\\nClick to enable\"}"
fi
