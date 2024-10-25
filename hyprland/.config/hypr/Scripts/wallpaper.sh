#!/bin/bash

interval=300
walldir=~/Pictures/
monitor=`hyprctl monitors | grep Monitor | awk '{print $2}'`

while true; do
    find $walldir -maxdepth 1 -type f | shuf | while read img; do
        #wal --cols16 -n -i  $img -p theme
        ln -f "$img" ~/.local/share/wallpapers/background

        hyprctl hyprpaper unload all
        hyprctl hyprpaper preload $img
        hyprctl hyprpaper wallpaper "$monitor, contain:$img"

        sleep $interval
    done
done
