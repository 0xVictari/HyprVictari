# Sourceado por gaming-mode-monitor.sh y gaming-mode-status.sh.
# find_game: imprime el juego que esta corriendo; falla si no hay ninguno.

GAMING_APPS_FILE="$HOME/.config/hypr/gaming-apps.conf"

# Emuladores/juegos nativos, por nombre de proceso. Steam no va aca: el cliente
# (steam, steamwebhelper) queda en la bandeja y nunca dejaria apagar el modo.
if [ -f "$GAMING_APPS_FILE" ]; then
    mapfile -t GAMING_APPS < <(grep -v '^#' "$GAMING_APPS_FILE" | grep -v '^[[:space:]]*$')
else
    GAMING_APPS=(retroarch melonds duckstation gzdoom woof nugget openmw)
fi

find_game() {
    local pid
    # Steam lanza cada juego (nativo o Proton) bajo "reaper SteamLaunch AppId=N",
    # que vive mientras el juego este abierto.
    pid=$(pgrep -o -f 'SteamLaunch AppId=')
    if [ -n "$pid" ]; then
        echo "Steam $(ps -o args= -p "$pid" | grep -o 'AppId=[0-9]*')"
        return 0
    fi
    (( ${#GAMING_APPS[@]} )) || return 1
    pid=$(pgrep -o -i "($(IFS='|'; echo "${GAMING_APPS[*]}"))") || return 1
    ps -o comm= -p "$pid"
}
