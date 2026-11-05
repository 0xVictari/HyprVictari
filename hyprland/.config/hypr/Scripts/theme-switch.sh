#!/bin/bash
# Selector de themes (Super+T).
#   theme-switch.sh            menu en wofi
#   theme-switch.sh <theme>    aplica themes/<theme>
#   theme-switch.sh --init     al iniciar Hyprland: crea themes/current si falta,
#                              aplica GTK/cursor/kitty y levanta waybar
#
# Un theme es una carpeta en ~/.config/hypr/themes/ con: hypr.lua, theme.sh,
# waybar.jsonc, waybar.css, wofi.css, dunstrc, hyprlock.conf, kitty.conf.
# El activo es el symlink themes/current (gitignoreado); config.jsonc/style.css
# de waybar, style.css de wofi, dunstrc y hyprlock.conf son symlinks a el.

themes=~/.config/hypr/themes
state=~/.local/state/theme-switch
current=$(readlink "$themes/current" 2>/dev/null)

list_themes() {
    local d
    for d in "$themes"/*/; do
        d=${d%/}; d=${d##*/}
        [[ $d != current && -f $themes/$d/theme.sh ]] && echo "$d"
    done
}

# Busca un theme de iconos/cursores o GTK en las rutas estandar
have_icons() { local d; for d in ~/.icons ~/.local/share/icons /usr/share/icons; do [[ -d $d/$1 ]] && return 0; done; return 1; }
have_gtk()   { local d; for d in ~/.themes ~/.local/share/themes /usr/share/themes; do [[ -d $d/$1 ]] && return 0; done; return 1; }

gs() { gsettings set org.gnome.desktop.interface "$@"; }

apply_gtk() {
    # shellcheck source=/dev/null
    source "$themes/$1/theme.sh"
    command -v gsettings >/dev/null || return

    # Primer cambio: guarda lo que habia, para los themes que dejan valores vacios
    if [[ ! -f $state/gtk-default ]]; then
        mkdir -p "$state"
        {
            printf 'DEF_GTK_THEME=%q\n'  "$(gsettings get org.gnome.desktop.interface gtk-theme  | tr -d "'")"
            printf 'DEF_ICON_THEME=%q\n' "$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")"
            printf 'DEF_FONT=%q\n'       "$(gsettings get org.gnome.desktop.interface font-name  | tr -d "'")"
        } > "$state/gtk-default"
    fi
    # shellcheck source=/dev/null
    source "$state/gtk-default"
    local gtk=${GTK_THEME:-$DEF_GTK_THEME} icons=${ICON_THEME:-$DEF_ICON_THEME} font=${FONT:-$DEF_FONT}
    missing=()

    if have_gtk "$gtk"; then gs gtk-theme "$gtk"; else missing+=("GTK $gtk"); fi
    if have_icons "$icons"; then gs icon-theme "$icons"; else missing+=("iconos $icons"); fi
    [[ -n $font ]] && gs font-name "$font"
    [[ -n $COLOR_SCHEME ]] && gs color-scheme "$COLOR_SCHEME"
    if have_icons "$CURSOR_THEME"; then
        gs cursor-theme "$CURSOR_THEME"
        gs cursor-size "$CURSOR_SIZE"
        hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE" >/dev/null
    else
        missing+=("cursor $CURSOR_THEME")
    fi
}

# kitty no esta stoweado en el desktop: kitty.conf local hace
# "include themes/theme.conf"; ese archivo pasa a ser symlink al theme.
apply_kitty() {
    local dir=~/.config/kitty target
    target=$dir/themes/theme.conf
    grep -qs 'include themes/theme.conf' "$dir/kitty.conf" || return
    # Si ~/.config/kitty apunta al repo (stow plegado) no tocarlo
    [[ $(readlink -f "$dir") == "$(readlink -f "$themes/../../../..")"/* ]] && return
    mkdir -p "$dir/themes"
    [[ -f $target && ! -L $target ]] && mv -n "$target" "$target.pre-theme-switch"
    ln -sfn "$themes/$1/kitty.conf" "$target"
    pkill -USR1 -x kitty   # kitty recarga la config
}

start_waybar() {
    killall -q waybar
    while pgrep -x waybar >/dev/null; do sleep 0.1; done
    setsid -f waybar >/dev/null 2>&1
}

apply() {
    local t=$1
    [[ -f $themes/$t/theme.sh ]] || { notify-send "Theme" "No existe: $t"; exit 1; }
    ln -sfn "$t" "$themes/current"
    apply_gtk "$t"
    apply_kitty "$t"
    hyprctl reload >/dev/null   # relee hypr.lua del theme
    start_waybar
    killall -q dunst            # D-Bus lo relanza con el dunstrc nuevo
    local msg="Theme: $NAME"
    (( ${#missing[@]} )) && msg+=$'\nNo instalado: '"${missing[*]}"
    notify-send -a theme-switch "Theme" "$msg"
}

case ${1-} in
    --init)
        [[ -n $current && -d $themes/$current ]] || { current=tokyonight; ln -sfn "$current" "$themes/current"; }
        apply_gtk "$current"
        apply_kitty "$current"
        start_waybar
        ;;
    "")
        pkill -x wofi && exit 0
        pick=$(list_themes | sed "s/^$current\$/& (activo)/" | wofi --dmenu --prompt "Theme" --width 300 --height 200 --cache-file /dev/null)
        pick=${pick% (activo)}
        [[ -n $pick && $pick != "$current" ]] && apply "$pick"
        ;;
    *)
        apply "$1"
        ;;
esac
