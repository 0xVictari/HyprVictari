#!/bin/bash
# Fondo aleatorio de ~/Pictures cada 5 min via IPC de hyprpaper.
# hyprpaper >= 0.8 no tiene preload/unload: "wallpaper" carga la imagen solo.
interval=300
walldir=~/Pictures

mkdir -p ~/.local/share/wallpapers

# Reintenta porque hyprpaper arranca a la vez que este script.
set_wallpaper() {
    local img=$1 mon try
    for mon in $(hyprctl monitors | awk '/^Monitor/ {print $2}'); do
        for try in {1..10}; do
            hyprctl hyprpaper wallpaper "$mon,$img,contain" >/dev/null && break
            sleep 1
        done
    done
}

while true; do
    mapfile -t imgs < <(find "$walldir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf)
    if (( ${#imgs[@]} == 0 )); then
        sleep "$interval"
        continue
    fi
    for img in "${imgs[@]}"; do
        ln -f "$img" ~/.local/share/wallpapers/background
        set_wallpaper "$img"
        sleep "$interval"
    done
done
