#!/bin/bash
# Super+Escape / boton "Apagar" de la taskbar de Chicago95: dialogo de apagado
# en wofi (toma el estilo del theme activo, wofi.css). Esc cancela.

pkill -x wofi && exit 0   # segunda pulsacion: cerrar (igual que Super+R)

# Orden fijo (--cache-file /dev/null: wofi no reordena por uso)
pick=$(printf '%s\n' \
    "⏻  Apagar el equipo" \
    "󰜉  Reiniciar el equipo" \
    "󰤄  Suspender" \
    "󰍃  Cerrar sesión" \
    "󰌾  Bloquear" |
    wofi --dmenu --prompt "Apagar el sistema" --width 320 --height 200 --cache-file /dev/null)

case $pick in
    *"Apagar el equipo")    systemctl poweroff ;;
    *"Reiniciar el equipo") systemctl reboot ;;
    *Suspender)             systemctl suspend ;;   # hypridle bloquea antes (before_sleep_cmd)
    *"Cerrar sesión")       hyprctl dispatch 'hl.dsp.exit()' ;;
    *Bloquear)              pidof hyprlock || hyprlock ;;
esac
