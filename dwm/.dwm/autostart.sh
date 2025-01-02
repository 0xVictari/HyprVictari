#!/bin/bash
xrandr --output eDP --mode 1280x720 --auto
#xrandr --output HDMI-A-0 --mode 1366x768
feh --bg-scale ~/Pictures/background &
sxhkd &
slstatus &
/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
xautolock -time 3 -locker "cinnamon-screensaver-command -l" \
 -killtime 15 -killer "systemctl suspend" &
