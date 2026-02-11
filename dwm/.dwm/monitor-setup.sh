#!/bin/bash
# monitor-setup.sh
if xrandr | grep "HDMI-1 connected"; then
    # Dual monitor setup
    xrandr --output eDP-1 --mode 1280x720 --auto
    xrandr --output HDMI-1 --mode 1920x1080 --above eDP-1
    # Optional: Set different wallpapers per monitor
    # feh --bg-scale ~/wallpaper1.jpg --bg-scale ~/wallpaper2.jpg
else
    # Single monitor setup
    xrandr --output eDP-1 --mode 1280x720 --auto
    xrandr --output HDMI-1 --off
fi
