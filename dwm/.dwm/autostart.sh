#!/bin/bash
# Function to setup monitors
setup_monitors() {
    if xrandr | grep "HDMI-1 connected"; then
        # Dual monitor setup
        xrandr --output eDP-1 --mode 1280x720 --auto
        xrandr --output HDMI-1 --mode 1920x1080 --above eDP-1
        echo "dual" > /tmp/dwm-monitor-state
    else
        # Single monitor setup
        xrandr --output eDP-1 --mode 1280x720 --auto
        xrandr --output HDMI-1 --off
        echo "single" > /tmp/dwm-monitor-state
    fi
}
# Setup monitors
setup_monitors

feh --bg-scale ~/Pictures/background &
sxhkd &
slstatus &
/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
xautolock -time 15 -locker "cinnamon-screensaver-command -l" \
 -killtime 30 -killer "systemctl suspend" &
picom -b &
