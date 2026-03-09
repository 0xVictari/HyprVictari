#!/bin/bash

STATE_FILE="/tmp/gaming-mode-state"
MONITOR_PID_FILE="/tmp/gaming-mode-monitor.pid"
INHIBIT_PID_FILE="/tmp/gaming-mode-inhibit.pid"
CONFIG_FILE="$HOME/.config/hypr/gaming-apps.conf"
LOG_FILE="/tmp/gaming-mode.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MONITOR] $1" >> "$LOG_FILE"
}

log "=== Monitor started (PID: $$) ==="

# Load gaming apps from config file or use defaults
if [ -f "$CONFIG_FILE" ]; then
    mapfile -t GAMING_APPS < <(grep -v '^#' "$CONFIG_FILE" | grep -v '^[[:space:]]*$')
    log "Loaded ${#GAMING_APPS[@]} apps from config file"
else
    GAMING_APPS=(
        "steam"
        "steam_app"
        "retroarch"
        "melonds"
        "duckstation"
        "gzdoom"
        "woof"
        "openmw"
    )
    log "Using default app list (${#GAMING_APPS[@]} apps)"
fi

# Log the app list
log "Monitoring apps: ${GAMING_APPS[*]}"

PATTERN=$(IFS='|'; echo "${GAMING_APPS[*]}")

check_gaming_apps() {
    local result=$(pgrep -i "($PATTERN)")
    if [ -n "$result" ]; then
        log "Found running apps: $(echo $result | xargs -I{} ps -p {} -o comm= | tr '\n' ', ')"
        return 0
    else
        return 1
    fi
}

# Initial grace period
log "Starting 30s grace period for apps to launch..."
sleep 30

IDLE_COUNT=0
MAX_IDLE_CHECKS=10  # 5 minutes

log "Starting monitoring loop (check every 30s, auto-disable after ${MAX_IDLE_CHECKS} checks)"

while [ -f "$STATE_FILE" ]; do
    if check_gaming_apps; then
        if [ $IDLE_COUNT -gt 0 ]; then
            log "Gaming app detected - resetting idle counter (was at $IDLE_COUNT/$MAX_IDLE_CHECKS)"
        fi
        IDLE_COUNT=0
    else
        ((IDLE_COUNT++))
        log "No gaming apps detected - idle count: $IDLE_COUNT/$MAX_IDLE_CHECKS"

        if [ $IDLE_COUNT -ge $MAX_IDLE_CHECKS ]; then
            log "=== AUTO-DISABLE TRIGGERED ==="
            notify-send "🎮 Gaming Mode" "Auto-disabling (no games for 5min)" -t 5000

            # Clean up
            rm "$STATE_FILE"
            log "Removed state file"

            rm "$MONITOR_PID_FILE" 2>/dev/null
            log "Removed monitor PID file"

            # Kill inhibitor
            if [ -f "$INHIBIT_PID_FILE" ]; then
                INHIBIT_PID=$(cat "$INHIBIT_PID_FILE")
                kill $INHIBIT_PID 2>/dev/null
                rm "$INHIBIT_PID_FILE"
                log "Killed inhibitor PID: $INHIBIT_PID"
            fi

            # Update waybar
            pkill -RTMIN+8 waybar
            log "Updated waybar"

            log "=== Monitor exiting (auto-disable) ==="
            exit 0
        fi
    fi

    sleep 30
done

# Clean exit (state file removed manually)
log "=== Monitor exiting (state file removed) ==="
rm "$MONITOR_PID_FILE" 2>/dev/null
