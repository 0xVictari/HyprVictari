#!/bin/bash
# Super+F1: lista en wofi los atajos de Hyprland que tienen description.
# Sale de "hyprctl binds -j", asi que siempre coincide con hyprland.lua.

pkill -x wofi && exit 0   # segunda pulsacion: cerrar (igual que Super+R)

hyprctl binds -j | python3 -I -c '
import json, sys

MODS = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]
KEYS = {
    "mouse:272": "Click izq", "mouse:273": "Click der",
    "mouse_down": "Rueda abajo", "mouse_up": "Rueda arriba",
    "left": "Izq", "right": "Der", "up": "Arriba", "down": "Abajo", "TAB": "Tab",
}

for b in json.load(sys.stdin):
    if not b.get("has_description"):
        continue
    combo = [name for bit, name in MODS if b["modmask"] & bit]
    combo.append(KEYS.get(b["key"], b["key"].removeprefix("XF86")))
    combo, desc = " + ".join(combo), b["description"]
    print(f"{combo:<26} {desc}")
' | wofi --dmenu --prompt "Atajos" --insensitive >/dev/null
