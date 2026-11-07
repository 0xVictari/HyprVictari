# shellcheck shell=bash disable=SC2034
# Lo lee Scripts/theme-switch.sh (source). Vacio = el valor que habia antes del
# primer cambio de theme (guardado en ~/.local/state/theme-switch/gtk-default);
# aca van explicitos para no depender de cuando se guardo ese archivo.
# Paquetes: qogir-gtk-theme (o ~/.themes/Qogir-Dark), papirus-icon-theme, qogir-icon-theme.
NAME="Tokyo Night"
GTK_THEME="Qogir-Dark"
ICON_THEME="Papirus-Dark"
FONT="Sans 10"
COLOR_SCHEME="prefer-dark"
# Vacio = el gtk-4.0/ del theme GTK instalado (~/.themes/Qogir-Dark/gtk-4.0)
GTK4_DIR=""
# Mantener igual a hl.env de hypr.lua. Qogir-Dark (qogir-icon-theme) es el que
# usa nwg-look; "Qogir-dark-cursors" no existe.
CURSOR_THEME="Qogir-Dark"
CURSOR_SIZE=24
