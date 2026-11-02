#!/bin/bash
# Super+B: alterna luz calida (4000K) <-> neutra (6500K) via IPC de hyprsunset.
# No usa "identity": hyprsunset no la refleja en "temperature" y el toggle perderia el estado.

if ! pgrep -x hyprsunset >/dev/null; then
    hyprsunset >/dev/null 2>&1 &
    disown
    sleep 1
fi

temp=$(hyprctl hyprsunset temperature)
if [[ $temp =~ ^[0-9]+$ ]] && (( temp < 5000 )); then
    hyprctl hyprsunset temperature 6500
else
    hyprctl hyprsunset temperature 4000
fi
