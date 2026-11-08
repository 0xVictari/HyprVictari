#!/bin/sh
# monitor-setup.sh: monitores de la sesión dwm + wallpaper.
# Lo corren autostart.sh al iniciar y Super+Shift+m (sxhkd) al enchufar o
# desenchufar una pantalla.
#
# Detecta las salidas con xrandr, sin nombres fijos (cambian según el driver:
# eDP-1/eDP1, HDMI-1/HDMI-A-0, DP-1/DisplayPort-0...):
#   - interna (eDP*, LVDS*, DSI*) + externa: la externa arriba de la interna
#   - una sola pantalla: esa
#   - las salidas desconectadas se apagan
# Se configura primero la interna y después la externa: dwm numera los
# monitores en ese orden (0 = interna), y las reglas de config.h lo usan.
#
# Ajustes de cada máquina, fuera del repo: ~/.config/dwm/monitors.local (sh).
# Sin ese archivo, cada pantalla usa su modo preferido y la externa va arriba.
# La laptop usa:
#   INTERNAL_MODE=1280x720
#   EXTERNAL_MODE=1920x1080
#   EXTERNAL_POS=above        # above | below | left-of | right-of

INTERNAL_MODE=
EXTERNAL_MODE=
EXTERNAL_POS=above
local_conf=${XDG_CONFIG_HOME:-$HOME/.config}/dwm/monitors.local
# shellcheck disable=SC1090
[ -f "$local_conf" ] && . "$local_conf"

# Modo pedido o, si no hay, el preferido de la pantalla
mode_args() { if [ -n "$1" ]; then echo "--mode $1"; else echo "--auto"; fi; }

query=$(xrandr --query)
internal= external=
for out in $(printf '%s\n' "$query" | awk '$2 == "connected" {print $1}'); do
    case $out in
        eDP*|LVDS*|DSI*) [ -n "$internal" ] || internal=$out ;;
        *)               [ -n "$external" ] || external=$out ;;
    esac
done

# Apagar lo desconectado (ej. el HDMI recién desenchufado), en una sola llamada
set --
for out in $(printf '%s\n' "$query" | awk '$2 == "disconnected" {print $1}'); do
    set -- "$@" --output "$out" --off
done
[ $# -gt 0 ] && xrandr "$@"

# shellcheck disable=SC2046  # mode_args se separa en palabras a propósito
if [ -n "$internal" ]; then
    xrandr --output "$internal" $(mode_args "$INTERNAL_MODE")
    [ -n "$external" ] &&
        xrandr --output "$external" $(mode_args "$EXTERNAL_MODE") --"$EXTERNAL_POS" "$internal"
elif [ -n "$external" ]; then
    xrandr --output "$external" $(mode_args "$EXTERNAL_MODE")
fi

# Wallpaper, para la geometría nueva
[ -f "$HOME/Pictures/background" ] && feh --bg-scale "$HOME/Pictures/background"
exit 0
