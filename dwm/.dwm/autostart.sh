#!/bin/bash
xrandr --output eDP --mode 1280x720 --auto
xrandr --output HDMI-A-0 --mode 1366x768
feh --bg-scale ~/Pictures/ar0wdypsajx41.png &
sxhkd &
slstatus &
/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &
