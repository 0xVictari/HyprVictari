# shellcheck shell=bash disable=SC2034
# Lo lee Scripts/theme-switch.sh (source). Paquete: chicago95-theme (AUR; trae
# GTK, iconos y cursores). Lo que no este instalado se saltea con un aviso.
NAME="Chicago95"
GTK_THEME="Chicago95"
ICON_THEME="Chicago95"
FONT="Sans 9"
COLOR_SCHEME="default"
# El paquete no trae GTK4: CSS propio (gtk-4.0/gtk.css), que theme-switch.sh
# enlaza en ~/.config/gtk-4.0
GTK4_DIR="gtk-4.0"
# Mantener igual a hl.env de hypr.lua. No Chicago95_Cursor_Black: solo trae
# nombres X11 (left_ptr, hand2) y no los de Wayland (default, pointer, text).
CURSOR_THEME="Chicago95 Standard Cursors Black"
CURSOR_SIZE=24
