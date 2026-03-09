#!/bin/bash

STATE_FILE="/tmp/gaming-mode-state"
MONITOR_PID_FILE="/tmp/gaming-mode-monitor.pid"
INHIBIT_PID_FILE="/tmp/gaming-mode-inhibit.pid"
LOG_FILE="/tmp/gaming-mode.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

if [ -f "$STATE_FILE" ]; then
    log "=== DISABLING Gaming Mode ==="

    # Kill the monitor process
    if [ -f "$MONITOR_PID_FILE" ]; then
        MONITOR_PID=$(cat "$MONITOR_PID_FILE")
        log "Killing monitor PID: $MONITOR_PID"
        kill $MONITOR_PID 2>/dev/null
        rm "$MONITOR_PID_FILE"
    else
        log "WARNING: Monitor PID file not found"
    fi

    # Kill the systemd inhibitor
    if [ -f "$INHIBIT_PID_FILE" ]; then
        INHIBIT_PID=$(cat "$INHIBIT_PID_FILE")
        log "Killing inhibitor PID: $INHIBIT_PID"
        kill $INHIBIT_PID 2>/dev/null
        rm "$INHIBIT_PID_FILE"
    else
        log "WARNING: Inhibitor PID file not found"
    fi

    rm "$STATE_FILE"
    log "Gaming mode disabled"

    notify-send "💤 Normal Mode" "Idle management restored" -t 3000
else
    log "=== ENABLING Gaming Mode ==="

    touch "$STATE_FILE"
    log "State file created"

    # Start systemd inhibitor
    systemd-inhibit --what=idle:sleep:handle-lid-switch \
                    --who="Gaming Mode" \
                    --why="Gaming session active" \
                    sleep infinity &
    INHIBIT_PID=$!
    echo $INHIBIT_PID > "$INHIBIT_PID_FILE"
    log "Started inhibitor with PID: $INHIBIT_PID"

    # Start the monitoring daemon
    ~/.config/hypr/Scripts/gaming-mode-monitor.sh &
    MONITOR_PID=$!
    echo $MONITOR_PID > "$MONITOR_PID_FILE"
    log "Started monitor with PID: $MONITOR_PID"

    notify-send "🎮 Gaming Mode ON" "Auto-disable when games close" -t 3000
fi

# Update waybar
pkill -RTMIN+8 waybar
log "Waybar updated"
