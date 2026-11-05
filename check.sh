#!/usr/bin/env bash
# Chequea los dotfiles contra lo instalado. Correrlo despues de "pacman -Syu"
# o al tocar configs:
#   ./check.sh           todo
#   ./check.sh --quick   sin levantar procesos de prueba
#
# Busca lo que una actualizacion rompe sin avisar: sintaxis que sigue siendo
# valida pero cambio de significado (dispatch de Hyprland 0.57, IPC de
# hyprpaper 0.8), opciones que una version borro (hyprlock 0.9), CSS que GTK
# rechaza, scripts renombrados que un bind sigue llamando. Sin --quick levanta
# una Waybar por theme (se ve una segunda barra ~4 s c/u) y un hypridle de prueba.
# Sale con 1 si algo falla.

cd "$(dirname "$(readlink -f "$0")")" || exit 1

QUICK=0
[[ ${1-} == --quick ]] && QUICK=1

HYPR=hyprland/.config/hypr
WAYBAR=waybar/.config/waybar
THEME_FILES=(theme.sh hypr.lua waybar.jsonc waybar.css wofi.css dunstrc hyprlock.conf kitty.conf)
mapfile -t THEMES < <(find "$HYPR/themes" -mindepth 1 -maxdepth 1 -type d | sort)   # sin el symlink current
fails=0

ok()      { printf '  \e[32mok\e[0m    %s\n' "$*"; }
fail()    { printf '  \e[31mFAIL\e[0m  %s\n' "$*"; fails=$((fails + 1)); }
warn()    { printf '  \e[33mwarn\e[0m  %s\n' "$*"; }
skip()    { printf '  --    %s\n' "$*"; }
section() { printf '\n\e[1m%s\e[0m\n' "$*"; }
detail()  { sed 's/^/          /'; }

in_hyprland() { [[ -n ${HYPRLAND_INSTANCE_SIGNATURE-} ]] && hyprctl version >/dev/null 2>&1; }

# trial SEG CMD...: corre CMD SEG segundos en su propia sesion, deja la salida
# en $log y el codigo en $rc (124 = seguia vivo). Mata la sesion entera: los
# hijos (cava de waybar) heredan el pipe y con "$(timeout ...)" el script
# quedaba colgado esperandolos.
trial() {
    local secs=$1 pid tmp; shift
    tmp=$(mktemp)
    setsid "$@" >"$tmp" 2>&1 </dev/null &
    pid=$!
    sleep "$secs"
    if kill -0 "$pid" 2>/dev/null; then
        rc=124
        pkill -s "$pid" 2>/dev/null
    else
        wait "$pid"; rc=$?
    fi
    wait "$pid" 2>/dev/null
    log=$(<"$tmp"); rm -f "$tmp"
}

if command -v pacman >/dev/null; then
    section "Versiones"
    pacman -Q hyprland hypridle hyprlock hyprpaper hyprsunset waybar waybar-git dunst 2>/dev/null | sort -u | sed 's/^/  /'
fi

# ---------------------------------------------------------------------------
section "Scripts"
mapfile -t scripts < <(git ls-files --cached --others --exclude-standard '*.sh')
bad=0
for f in "${scripts[@]}"; do
    out=$(bash -n "$f" 2>&1) || { fail "bash -n $f"; detail <<<"$out"; bad=1; }
done
(( bad )) || ok "sintaxis de ${#scripts[@]} scripts (bash -n)"

if command -v shellcheck >/dev/null; then
    if out=$(shellcheck -s bash -S error "${scripts[@]}" 2>&1); then
        ok "shellcheck sin errores"
    else
        fail "shellcheck"; detail <<<"$out"
    fi
    n=$(shellcheck -s bash -S warning -f gcc "${scripts[@]}" 2>/dev/null | wc -l)
    (( n )) && warn "shellcheck: $n advertencias (ver con: shellcheck -S warning <script>)"
else
    skip "shellcheck no instalado (sudo pacman -S shellcheck)"
fi

# Los binds y modulos llaman scripts por ruta: si se renombra uno, falla en silencio
missing=()
while read -r s; do
    [[ -x $HYPR/Scripts/$s ]] || missing+=("$s")
done < <(grep -shoE 'Scripts/[A-Za-z0-9_.-]+\.sh' "$HYPR"/*.lua "$HYPR"/*.conf "$HYPR"/Scripts/*.sh "${THEMES[@]/%//*}" | sed 's|^Scripts/||' | sort -u)
if (( ${#missing[@]} )); then
    fail "scripts referenciados que no existen o no son ejecutables:"; printf '%s\n' "${missing[@]}" | detail
else
    ok "todos los Scripts/*.sh referenciados existen y son ejecutables"
fi

# ---------------------------------------------------------------------------
section "Themes"
cur=$(readlink "$HYPR/themes/current")
if [[ -n $cur && -d $HYPR/themes/$cur ]]; then
    ok "theme activo: $cur"
else
    warn "sin themes/current: se crea al iniciar Hyprland (theme-switch.sh --init)"
fi
bad=0
for t in "${THEMES[@]}"; do
    for f in "${THEME_FILES[@]}"; do
        [[ -f $t/$f ]] || { fail "${t##*/}: falta $f"; bad=1; }
    done
done
(( bad )) || ok "${#THEMES[@]} themes completos (${THEME_FILES[*]})"
# Los archivos vivos tienen que ser symlinks al theme activo, no copias
for f in "$WAYBAR"/config.jsonc "$WAYBAR"/style.css wofi/.config/wofi/style.css dunst/.config/dunst/dunstrc "$HYPR"/hyprlock.conf; do
    [[ $(readlink "$f") == *themes/current/* ]] || fail "$f no es symlink a themes/current"
done

# ---------------------------------------------------------------------------
section "Hyprland"
if command -v luac >/dev/null; then
    if out=$(luac -p "$HYPR"/*.lua "${THEMES[@]/%//hypr.lua}" 2>&1); then ok "sintaxis Lua"; else fail "luac -p"; detail <<<"$out"; fi
else
    skip "luac no instalado"
fi

# Con config Lua, "hyprctl dispatch dpms on" da error: va 'hl.dsp.dpms({action = "on"})'
if out=$(grep -rnE "hyprctl dispatch +['\"]?[a-z]" "$HYPR" "$WAYBAR" | grep -vE "hyprctl dispatch +['\"]?hl\."); then
    fail "hyprctl dispatch con sintaxis vieja (usar 'hl.dsp...')"; detail <<<"$out"
else
    ok "hyprctl dispatch con sintaxis Lua"
fi

if in_hyprland; then
    out=$(hyprctl configerrors | grep '[^[:space:]]')
    if [[ -z $out ]]; then ok "hyprctl configerrors vacio"; else fail "hyprctl configerrors"; detail <<<"$out"; fi
    n=$(hyprctl binds -j | python3 -I -c 'import json,sys; print(sum(not b["has_description"] for b in json.load(sys.stdin)))')
    if (( n )); then warn "$n binds sin description (no salen en Super+F1)"; else ok "todos los binds tienen description"; fi
else
    skip "sin sesion de Hyprland: configerrors y binds"
fi

# hyprpaper >= 0.8 no tiene preload/unload/listloaded
if out=$(grep -snE 'hyprpaper +(preload|unload|listloaded)|^[[:space:]]*preload[[:space:]]*=' "$HYPR"/*.conf "$HYPR"/Scripts/*.sh); then
    fail "hyprpaper: comandos que ya no existen"; detail <<<"$out"
else
    ok "hyprpaper sin preload/unload"
fi

# hyprlock no tiene modo de chequeo (correrlo bloquea la pantalla). Heuristica:
# una opcion es valida si esta en el ejemplo que trae el paquete o entre las
# cadenas del binario (las cortas el compilador las guarda inline: van en el
# ejemplo o en la lista fija). hyprlock ignora las desconocidas, por eso warn.
if hl=$(command -v hyprlock) && command -v strings >/dev/null; then
    known=$(strings "$hl"
            sed -nE 's/^[[:space:]]*#?[[:space:]]*([a-z_]+)[[:space:]]*=.*/\1/p' /usr/share/hypr/hyprlock.conf 2>/dev/null
            printf '%s\n' color)
    for t in "${THEMES[@]}"; do
        unknown=()
        while read -r key; do
            grep -qE "(^|:)${key}\$" <<<"$known" || unknown+=("$key")
        done < <(sed -nE 's/^[[:space:]]*([a-z_]+)[[:space:]]*=.*/\1/p' "$t"/hyprlock.conf | sort -u)
        if (( ${#unknown[@]} )); then
            warn "${t##*/}/hyprlock.conf: opciones que esta version parece no conocer (las ignora):"; printf '%s\n' "${unknown[@]}" | detail
        else
            ok "${t##*/}/hyprlock.conf: todas las opciones existen"
        fi
    done
else
    skip "hyprlock o strings no instalados"
fi

if (( ! QUICK )) && in_hyprland; then
    trial 2 hypridle -c "$HYPR"/hypridle.conf
    out=$(grep -E 'Config error' <<<"$log")
    if [[ -z $out ]]; then ok "hypridle.conf"; else fail "hypridle.conf"; detail <<<"$out"; fi
else
    skip "hypridle.conf (--quick o sin Hyprland)"
fi

# ---------------------------------------------------------------------------
section "Waybar"
if (( ! QUICK )) && [[ -n ${WAYLAND_DISPLAY-} ]] && command -v waybar >/dev/null; then
    for t in "${THEMES[@]}"; do
        trial 4 waybar -c "$t"/waybar.jsonc -s "$t"/waybar.css -l warning
        # Ruido esperado: el desktop no tiene bateria; iconos del tray de algunas apps
        out=$(grep -E '\[(warning|error|critical)\]' <<<"$log" | grep -vE 'No batteries|No icon name or pixmap')
        if (( rc != 124 )); then
            fail "${t##*/}: waybar se cerro solo (codigo $rc)"; detail <<<"$log"
        elif [[ -n $out ]]; then
            fail "${t##*/}: waybar reporto problemas (CSS, modulos desactivados...)"; detail <<<"$out"
        else
            ok "${t##*/}: waybar.jsonc + waybar.css cargan sin advertencias"
        fi
    done
else
    skip "waybar (--quick o sin Wayland)"
fi

# ---------------------------------------------------------------------------
section "Resultado"
if (( fails )); then
    printf '  \e[31m%d chequeo(s) fallaron\e[0m\n' "$fails"
    exit 1
fi
printf '  \e[32mtodo ok\e[0m\n'
