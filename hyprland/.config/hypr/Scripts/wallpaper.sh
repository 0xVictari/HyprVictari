#!/bin/bash
interval=300
walldir=~/Pictures/
monitor=$(hyprctl monitors | grep Monitor | awk '{print $2}')

# Get list of already preloaded wallpapers to clean up
cleanup_old_wallpapers() {
    # Unload previous wallpaper if you're tracking it
    if [ -f /tmp/current_wallpaper ]; then
        old_img=$(cat /tmp/current_wallpaper)
        hyprctl hyprpaper unload "$old_img" 2>/dev/null
    fi
}

while true; do
    find "$walldir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf | while read -r img; do
        cleanup_old_wallpapers

        # Create symlink
        ln -f "$img" ~/.local/share/wallpapers/background

        # Preload and set wallpaper
        hyprctl hyprpaper preload "$img"
        hyprctl hyprpaper wallpaper "$monitor,$img, contain"

        # Store current wallpaper for next cleanup
        echo "$img" > /tmp/current_wallpaper

        sleep $interval
    done
done
