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
# una Waybar (se ve una segunda barra ~4 s) y un hypridle de prueba.
# Sale con 1 si algo falla.

cd "$(dirname "$(readlink -f "$0")")" || exit 1

QUICK=0
[[ ${1-} == --quick ]] && QUICK=1

HYPR=hyprland/.config/hypr
WAYBAR=waybar/.config/waybar
fails=0

ok()      { printf '  \e[32mok\e[0m    %s\n' "$*"; }
fail()    { printf '  \e[31mFAIL\e[0m  %s\n' "$*"; fails=$((fails + 1)); }
warn()    { printf '  \e[33mwarn\e[0m  %s\n' "$*"; }
skip()    { printf '  --    %s\n' "$*"; }
section() { printf '\n\e[1m%s\e[0m\n' "$*"; }
detail()  { sed 's/^/          /'; }

in_hyprland() { [[ -n ${HYPRLAND_INSTANCE_SIGNATURE-} ]] && hyprctl version >/dev/null 2>&1; }

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
done < <(grep -ohE 'Scripts/[A-Za-z0-9_.-]+\.sh' "$HYPR"/*.lua "$HYPR"/*.conf "$HYPR"/Scripts/*.sh "$WAYBAR"/config.jsonc | sed 's|^Scripts/||' | sort -u)
if (( ${#missing[@]} )); then
    fail "scripts referenciados que no existen o no son ejecutables:"; printf '%s\n' "${missing[@]}" | detail
else
    ok "todos los Scripts/*.sh referenciados existen y son ejecutables"
fi

# ---------------------------------------------------------------------------
section "Hyprland"
if command -v luac >/dev/null; then
    if out=$(luac -p "$HYPR"/*.lua 2>&1); then ok "sintaxis Lua"; else fail "luac -p"; detail <<<"$out"; fi
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
if out=$(grep -nE 'hyprpaper +(preload|unload|listloaded)|^[[:space:]]*preload[[:space:]]*=' "$HYPR"/*.conf "$HYPR"/Scripts/*.sh); then
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
    unknown=()
    while read -r key; do
        grep -qE "(^|:)${key}\$" <<<"$known" || unknown+=("$key")
    done < <(sed -nE 's/^[[:space:]]*([a-z_]+)[[:space:]]*=.*/\1/p' "$HYPR"/hyprlock.conf | sort -u)
    if (( ${#unknown[@]} )); then
        warn "hyprlock.conf: opciones que esta version parece no conocer (las ignora):"; printf '%s\n' "${unknown[@]}" | detail
    else
        ok "hyprlock.conf: todas las opciones existen"
    fi
else
    skip "hyprlock o strings no instalados"
fi

if (( ! QUICK )) && in_hyprland; then
    out=$(timeout 2 hypridle -c "$HYPR"/hypridle.conf 2>&1 | grep -E 'Config error')
    if [[ -z $out ]]; then ok "hypridle.conf"; else fail "hypridle.conf"; detail <<<"$out"; fi
else
    skip "hypridle.conf (--quick o sin Hyprland)"
fi

# ---------------------------------------------------------------------------
section "Waybar"
if (( ! QUICK )) && [[ -n ${WAYLAND_DISPLAY-} ]] && command -v waybar >/dev/null; then
    log=$(timeout 4 waybar -c "$WAYBAR"/config.jsonc -s "$WAYBAR"/style.css -l warning 2>&1)
    rc=$?
    # Ruido esperado: el desktop no tiene bateria; iconos del tray de algunas apps
    out=$(grep -E '\[(warning|error|critical)\]' <<<"$log" | grep -vE 'No batteries|No icon name or pixmap')
    if (( rc != 124 )); then
        fail "waybar se cerro solo (codigo $rc)"; detail <<<"$log"
    elif [[ -n $out ]]; then
        fail "waybar reporto problemas (CSS, modulos desactivados...)"; detail <<<"$out"
    else
        ok "config.jsonc + style.css cargan sin advertencias"
    fi
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
