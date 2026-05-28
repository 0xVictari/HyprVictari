#!/usr/bin/env bash
#
# artix-post-install.sh
#
# Post-instalacion de un sistema Artix base (dinit) para desktop.
# Se corre YA LOGUEADO en el sistema instalado (no en el live), con red.
#
# Modular por flags:
#   sudo ./artix-post-install.sh --core       # paru + ly + sesion base (audio, polkit, elogind)
#   sudo ./artix-post-install.sh --hyprland   # stack Hyprland
#   sudo ./artix-post-install.sh --fallback   # Cinnamon + XLibre (sesion de respaldo)
#   sudo ./artix-post-install.sh --apps       # apps de usuario + theming (monolitico)
#   sudo ./artix-post-install.sh --cosmetics  # tema GRUB + Plymouth opcional
#   sudo ./artix-post-install.sh --all         # core -> hyprland -> fallback -> apps -> cosmetics
#
# Orden de dependencias:  core  ->  (hyprland | fallback)  ->  apps
# El core debe correr primero (instala paru y deja ly funcional).
#
# DOTFILES: fuera de scope. Trae tus dotfiles a mano (git/stow/rsync).
# Este script solo instala los PAQUETES que esos dotfiles necesitan.
#
# Idempotente donde es posible: --needed en pacman evita reinstalar, los
# fixes de ly detectan estado antes de tocar. Correr un modulo dos veces
# no rompe nada.
#
# USO: requiere sudo. Detecta el usuario real via $SUDO_USER para las
# builds de AUR (paru no corre como root).

set -euo pipefail

# =============================================================================
# VARIABLES DE DISENO (listas de paquetes editables)
# =============================================================================

# --- ly: valores descubiertos en este hardware (de tu script de ly) ---
LY_ACTIVE_CONSOLES='/dev/tty[3-6]'
LY_XWRAPPER_ALLOWED_USERS='anybody'
LY_XWRAPPER_NEEDS_ROOT='yes'

# --- Paquetes core (repos oficiales) ---
CORE_PACKAGES="base-devel git \
elogind-dinit \
polkit polkit-gnome \
pipewire pipewire-pulse pipewire-alsa wireplumber \
pipewire-dinit pipewire-pulse-dinit wireplumber-dinit \
pipewire-audio pipewire-session-manager \
dbus-dinit dbus-dinit-user \
rtkit \
gst-plugin-pipewire \
alsa-utils alsa-plugins alsa-firmware \
pavucontrol \
xdg-user-dirs xdg-utils \
brightnessctl \
gnome-keyring \
vulkan-intel \
gnu-netcat"

# --- Hyprland stack (repos oficiales) ---
HYPRLAND_PACKAGES="hyprland hypridle hyprlock hyprpaper hyprsunset \
xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
qt5-wayland qt6-wayland \
waybar \
dunst wofi wlogout \
kitty \
grim slurp wl-clipboard \
flameshot \
imagemagick \
ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-go-nerd \
ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono ttf-meslo-nerd \
noto-fonts noto-fonts-cjk noto-fonts-emoji \
ttf-liberation ttf-dejavu"

# --- Hyprland: paquetes de AUR ---
# NOTA: waybar va por repos OFICIALES (no waybar-git). La version 0.15+ de
# Artix esta compilada contra elogind (ABI-compatible con libsystemd via
# drop-in), no contra systemd. El problema viejo de los botones de workspace
# era por una version desactualizada, ya resuelto en repos.
HYPRLAND_AUR="icat"

# --- Fallback: Cinnamon + XLibre (sesion de respaldo) ---
# XLibre es el X server por defecto en Artix desde 20260402, reemplaza
# xorg-server. El Xwrapper.config del modulo core esta pensado para XLibre.
#
# CRITICO: este modulo DEBE correr ANTES de --hyprland en una instalacion
# limpia. Si Hyprland se instala primero, trae xorg-xwayland como dep, que
# arrastra xorg-server-common, y despues XLibre conflictua. Con el orden
# correcto (XLibre primero), xlibre-xserver-common queda como el 'common'
# del sistema y xorg-xwayland se acomoda a el via provides/replaces.
# Referencia: guia oficial de instalacion Artix+dinit+Hyprland con XLibre.
FALLBACK_PACKAGES="cinnamon \
xlibre-xserver \
xlibre-input-libinput \
xlibre-video-intel \
xorg-xinit \
xterm"

# --- Apps de usuario + theming (monolitico) ---
APPS_PACKAGES="neovim zed \
mpv vlc \
signal-desktop telegram-desktop \
libreoffice-still \
nemo \
xed xreader xviewer \
gthumb \
syncthing \
yt-dlp \
btop ripgrep ncdu duf pv \
unrar unzip rsync wget \
fastfetch \
papirus-icon-theme \
nwg-look kvantum qt5ct qt6ct \
power-profiles-daemon \
ufw \
stow"

# --- Apps: paquetes de AUR ---
# Solo lo que buildea consistentemente en Artix.
# Si necesitas pix, xplayer, obsidian-bin u otros: paru -S <paquete> a mano.
APPS_AUR="oh-my-posh-bin \
nemo-fileroller \
qogir-gtk-theme qogir-icon-theme qogir-cursor-theme \
zap-git"

# =============================================================================
# HELPERS
# =============================================================================

log()  { printf '\033[1;32m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

confirm() {
    local msg="$1" answer
    printf '\033[1;33m%s [y/N]:\033[0m ' "$msg"
    read -r answer
    [[ "$answer" =~ ^[yY]$ ]]
}

require_root() { [[ "$(id -u)" -eq 0 ]] || die "Correr como root (sudo)."; }

# Usuario real (no root) para las builds de AUR
REAL_USER="${SUDO_USER:-}"
REAL_HOME=""

detect_user() {
    [[ -n "$REAL_USER" ]] || die "No se detecto \$SUDO_USER. Corre con: sudo $0 ..."
    REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
    [[ -n "$REAL_HOME" ]] || die "No se pudo determinar el home de $REAL_USER."
    log "Usuario real: $REAL_USER (home: $REAL_HOME)"
}

check_network() {
    ping -c1 -W3 1.1.1.1 >/dev/null 2>&1 || die "Sin conexion a internet."
    log "Conectividad OK"
}

pac() { pacman -S --needed --noconfirm "$@"; }

# Variante que acepta automaticamente reemplazos de paquetes en conflicto.
# Necesaria cuando se instalan paquetes que reemplazan otros (XLibre vs
# Xorg). --ask=4 = NoDepVersion+IgnoreDep_dependent: pacman responde Y a
# "Remove xorg-server-common?" cuando un paquete entra en conflicto con
# uno instalado y hay relacion de provides/replaces.
pac_replace() { pacman -S --needed --noconfirm --ask=4 "$@"; }

# Correr paru como el usuario real (no root)
aur() {
    sudo -u "$REAL_USER" paru -S --needed --noconfirm "$@"
}

TS="$(date +%Y%m%d-%H%M%S)"
backup() { [[ -f "$1" ]] && cp -a "$1" "${1}.bak-${TS}" && log "Backup: ${1}.bak-${TS}" || true; }

# --- Mantener vivo el sudo timestamp durante toda la corrida ---
# El script corre apt/paru y builds de AUR que tardan; sin esto, sudo
# pediria password en medio. El drop-in es temporal y se borra en exit.
SUDO_DROPIN="/etc/sudoers.d/99-postinstall-temp"

sudo_extend() {
    [[ -f "$SUDO_DROPIN" ]] && return
    # Extender timeout del sudo en curso Y dar NOPASSWD temporal al usuario
    # real. Sin el NOPASSWD, los 'sudo -u $REAL_USER paru/makepkg' que el
    # script lanza para builds de AUR crean sesiones sudo nuevas que pediran
    # password (no heredan el timestamp). Con NOPASSWD durante la corrida,
    # paru/makepkg no interrumpen para pedir password.
    cat > "$SUDO_DROPIN" <<EOF
Defaults timestamp_timeout=120
${REAL_USER:-anon} ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 "$SUDO_DROPIN"
    log "Sudo: timeout extendido + NOPASSWD temporal para ${REAL_USER:-usuario}."
}

sudo_restore() {
    [[ -f "$SUDO_DROPIN" ]] && rm -f "$SUDO_DROPIN" && log "Sudo: restaurado (NOPASSWD removido, timeout default)."
}

# Garantizar restore aunque el script falle o se interrumpa
trap sudo_restore EXIT INT TERM

# =============================================================================
# CORE: paru + ly + sesion base
# =============================================================================

install_paru() {
    if command -v paru >/dev/null 2>&1; then
        log "paru ya esta instalado."
        return
    fi
    log "Instalando paru desde AUR..."
    pac base-devel git
    # Build como usuario real en un tmpdir
    sudo -u "$REAL_USER" bash -c '
        set -e
        tmp="$(mktemp -d)"
        cd "$tmp"
        git clone https://aur.archlinux.org/paru.git
        cd paru
        makepkg -si --noconfirm
        cd /
        rm -rf "$tmp"
    '
    command -v paru >/dev/null 2>&1 || die "Fallo la instalacion de paru."
    log "paru instalado."
}

# --- Fixes de ly (integrado de tu setup-ly-artix-dinit.sh) ---
setup_ly() {
    log "Instalando y configurando ly..."
    pac ly ly-dinit

    local LY_SERVICE="/etc/dinit.d/ly"
    local CONSOLE_CONF="/etc/dinit.d/config/console.conf"
    local XWRAPPER_CONF="/etc/X11/Xwrapper.config"

    [[ -f "$LY_SERVICE" ]] || die "No existe $LY_SERVICE tras instalar ly-dinit."

    # Resolver binario real (fix de $EXE_NAME vacio)
    local LY_BIN=""
    for cand in /usr/bin/ly-dm /usr/bin/ly; do
        [[ -x "$cand" ]] && LY_BIN="$cand" && break
    done
    [[ -n "$LY_BIN" ]] || die "No se encontro el binario de ly."
    log "Binario de ly: $LY_BIN"

    # Target de login real (fix de 'loginready' inexistente)
    local LOGIN_DEP=""
    for dep in login.target loginready; do
        if [[ -e "/etc/dinit.d/${dep}" ]] || [[ -e "/usr/lib/dinit.d/${dep}" ]]; then
            LOGIN_DEP="$dep"; break
        fi
    done
    [[ -z "$LOGIN_DEP" ]] && grep -rq 'login.target' /etc/dinit.d/ /usr/lib/dinit.d/ 2>/dev/null && LOGIN_DEP="login.target"

    # Aplicar fixes al service file si hacen falta
    local need_edit=0
    grep -q "^command[[:space:]]*=[[:space:]]*${LY_BIN}\$" "$LY_SERVICE" || need_edit=1
    grep -q 'loginready' "$LY_SERVICE" && need_edit=1
    if [[ "$need_edit" -eq 1 ]]; then
        backup "$LY_SERVICE"
        if grep -qE '^command[[:space:]]*=' "$LY_SERVICE"; then
            sed -i -E "s|^command[[:space:]]*=.*|command         = ${LY_BIN}|" "$LY_SERVICE"
        else
            printf 'command         = %s\n' "$LY_BIN" >> "$LY_SERVICE"
        fi
        if [[ -n "$LOGIN_DEP" ]]; then
            if grep -qE '^[[:space:]]*#?[[:space:]]*depends-on[[:space:]]*=' "$LY_SERVICE"; then
                sed -i -E "s|^[[:space:]]*#?[[:space:]]*depends-on[[:space:]]*=.*|depends-on      = ${LOGIN_DEP}|" "$LY_SERVICE"
            else
                printf 'depends-on      = %s\n' "$LOGIN_DEP" >> "$LY_SERVICE"
            fi
        fi
        log "Service file de ly corregido."
    else
        log "Service file de ly ya esta correcto."
    fi

    # Liberar TTYs bajos
    if [[ -f "$CONSOLE_CONF" ]]; then
        if ! grep -q "ACTIVE_CONSOLES=\"${LY_ACTIVE_CONSOLES}\"" "$CONSOLE_CONF"; then
            backup "$CONSOLE_CONF"
            sed -i -E "s|^ACTIVE_CONSOLES=.*|ACTIVE_CONSOLES=\"${LY_ACTIVE_CONSOLES}\"|" "$CONSOLE_CONF"
            log "ACTIVE_CONSOLES -> ${LY_ACTIVE_CONSOLES}"
        fi
    fi

    # Xwrapper para XLibre
    mkdir -p /etc/X11
    local want_xw
    want_xw="$(printf 'allowed_users = %s\nneeds_root_rights = %s\n' "$LY_XWRAPPER_ALLOWED_USERS" "$LY_XWRAPPER_NEEDS_ROOT")"
    if [[ ! -f "$XWRAPPER_CONF" ]] || [[ "$(cat "$XWRAPPER_CONF")" != "$want_xw" ]]; then
        backup "$XWRAPPER_CONF"
        printf '%s' "$want_xw" > "$XWRAPPER_CONF"
        log "Xwrapper.config escrito."
    fi

    # Habilitar ly
    ln -sf /etc/dinit.d/ly /etc/dinit.d/boot.d/ly
    log "ly habilitado en boot."

    # Skin: animacion matrix + TTY explicito + idioma
    local LY_CONFIG="/etc/ly/config.ini"
    if [[ -f "$LY_CONFIG" ]]; then
        backup "$LY_CONFIG"
        # IMPORTANTE: idempotente. Borramos TODAS las lineas 'animation' previas
        # (comentadas o no) antes de agregar la nueva. Evita duplicacion en
        # corridas sucesivas del script.
        sed -i -E '/^#?\s*animation\s*=/d' "$LY_CONFIG"
        echo "animation = matrix" >> "$LY_CONFIG"
        log "ly skin -> matrix"

        # TTY explicito: ly DEBE correr en una TTY donde NO haya getty.
        # console.conf libera tty1-tty2 del rango ACTIVE_CONSOLES=tty[3-6],
        # pero dinit puede instanciar un getty en tty1 igual. Usar tty=2
        # garantiza que no haya getty compitiendo por el input (sintoma:
        # caracteres del password aparecen como teclas literales sin enmascarar
        # y el cursor no avanza hasta hacer Ctrl+C que mata al getty
        # intermediario). Doc oficial de ly: "you must disable the TTY service
        # that Ly will run on, otherwise bad things will happen."
        sed -i -E '/^#?\s*tty\s*=/d' "$LY_CONFIG"
        echo "tty = 2" >> "$LY_CONFIG"
        log "ly TTY -> 2 (libre de getty segun console.conf)"
    else
        warn "$LY_CONFIG no existe; no se pudo setear el skin matrix."
    fi

    warn "Tras 'paru -Syu' que actualice ly-dinit, revisa .pacnew en $LY_SERVICE."

    # --- Fix del rendering de ly tras transicion desde Plymouth ---
    # PROBLEMA RESUELTO: al boot con Plymouth, el prompt de password de ly
    # no enmascaraba con asteriscos y los caracteres se sobrescribian en la
    # misma posicion sin avanzar el cursor (workaround temporal: Ctrl+C).
    # CAUSA: Plymouth deja el VT con line discipline / atributos en estado
    # inconsistente, y ly no resetea el terminal antes de tomar control.
    # FIX: stty sane + tput reset en /etc/ly/startup.sh, que ly ejecuta
    # ANTES de tomar control del TTY (segun el header del propio archivo).
    # Diagnostico aislado experimentalmente: sin Plymouth, ly funciona normal.
    local LY_STARTUP="/etc/ly/startup.sh"
    if [[ -f "$LY_STARTUP" ]]; then
        # Guard especifico: busca el escape RIS, no solo 'stty sane'. Asi una
        # version vieja del fix (con tput reset) SI se actualiza a la nueva.
        if ! grep -q '033c' "$LY_STARTUP"; then
            backup "$LY_STARTUP"
            cat > "$LY_STARTUP" <<'STARTUP_EOF'
#!/bin/sh
# This file is executed when starting Ly (before the TTY is taken control of)

# Reset del TTY tras la transicion desde Plymouth.
# Plymouth deja el VT con line discipline / atributos en estado inconsistente,
# causando que ly no renderice asteriscos en el prompt de password ni avance
# el cursor (workaround conocido: Ctrl+C). Este reset normaliza el terminal
# antes de que ly tome control. Se usa el escape sequence crudo (\033c, full
# reset RIS) ademas de stty, porque tput reset depende de terminfo y puede
# no estar disponible/correcto tan temprano en el boot.
if [ "$TERM" = "linux" ] || [ -z "$TERM" ]; then
    # RIS (Reset to Initial State) - escape sequence crudo, no depende de tput
    printf '\033c' > /dev/console 2>/dev/null
    printf '\033c' 2>/dev/null
    # stty sane sobre el TTY de la consola
    /usr/bin/stty sane 2>/dev/null
    /usr/bin/stty sane < /dev/console 2>/dev/null
fi
STARTUP_EOF
            chmod +x "$LY_STARTUP"
            log "ly startup.sh: reset de TTY agregado (fix Plymouth->ly)."
        else
            log "ly startup.sh ya tiene el fix de reset."
        fi
    else
        warn "$LY_STARTUP no existe; el fix de transicion Plymouth->ly no se aplico."
    fi
}

module_core() {
    log "==================== MODULO CORE ===================="
    check_network
    detect_user
    confirm "Instalar core (paru + ly + sesion base)?" || return

    pac $CORE_PACKAGES
    install_paru
    setup_ly

    # --- Servicios dinit del core (system level) ---
    ln -sf /etc/dinit.d/dbus /etc/dinit.d/boot.d/dbus 2>/dev/null || true
    # dinit-user-spawn: CRITICO. Arranca los user services de cada usuario al
    # login. pipewire/wireplumber corren como USER services, no system. Sin
    # esto, pipewire nunca arranca en la sesion -> waybar no conecta al stream
    # de audio, apps sin sonido. La ISO oficial de Artix lo tiene en boot.d.
    if [[ -e /lib/dinit.d/dinit-user-spawn ]]; then
        ln -sf /lib/dinit.d/dinit-user-spawn /etc/dinit.d/boot.d/dinit-user-spawn 2>/dev/null || true
    elif [[ -e /usr/lib/dinit.d/dinit-user-spawn ]]; then
        ln -sf /usr/lib/dinit.d/dinit-user-spawn /etc/dinit.d/boot.d/dinit-user-spawn 2>/dev/null || true
    fi
    log "dinit-user-spawn habilitado (necesario para pipewire user service)."

    # --- User services de audio (pipewire/wireplumber/pulse + dbus) ---
    # Replicamos EXACTAMENTE lo que hace la ISO oficial de Artix: crear
    # symlinks en ~/.config/dinit.d/boot.d/ apuntando a /etc/dinit.d/user/.
    # Asi dinit-user-spawn (habilitado arriba) los arranca al login.
    # Los service files vienen de los paquetes *-dinit en /etc/dinit.d/user/.
    # Verificado contra instalacion Calamares: estos 4 son los que habilita.
    sudo -u "$REAL_USER" sh -c '
        mkdir -p "$HOME/.config/dinit.d/boot.d"
        for svc in dbus pipewire wireplumber pipewire-pulse; do
            if [ -e "/etc/dinit.d/user/$svc" ]; then
                ln -sf "/etc/dinit.d/user/$svc" "$HOME/.config/dinit.d/boot.d/$svc"
            fi
        done
    '
    log "User services de audio habilitados (dbus, pipewire, wireplumber, pipewire-pulse)."

    # Marcar que el core corrio
    touch /var/lib/.artix-post-core-done
    log "Core completado."
    warn "Los user services de audio arrancan al PROXIMO login (o reboot)."
    warn "Verifica tras reloguear: dinitctl --user list | grep pipewire"
}

require_core() {
    [[ -f /var/lib/.artix-post-core-done ]] || die "Corre primero el modulo --core."
}

# =============================================================================
# MODULO HYPRLAND
# =============================================================================

module_hyprland() {
    log "================== MODULO HYPRLAND =================="
    require_core
    check_network
    detect_user
    confirm "Instalar el stack de Hyprland?" || return

    pac $HYPRLAND_PACKAGES
    # shellcheck disable=SC2086
    aur $HYPRLAND_AUR

    # Session file (por si el paquete no lo trae)
    if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
        mkdir -p /usr/share/wayland-sessions
        cat > /usr/share/wayland-sessions/hyprland.desktop <<DESKTOP
[Desktop Entry]
Name=Hyprland
Comment=Dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DESKTOP
        log "Session file de Hyprland creado."
    fi

    log "Hyprland instalado. Trae tu ~/.config/hypr a mano (dotfiles)."
}

# =============================================================================
# MODULO FALLBACK (Cinnamon + XLibre)
# =============================================================================

module_fallback() {
    log "============ MODULO FALLBACK (Cinnamon + XLibre) ============"
    require_core
    check_network
    confirm "Instalar Cinnamon + XLibre como sesion de respaldo?" || return

    # pac_replace: acepta automaticamente "Remove xorg-server-common?"
    # cuando xlibre-xserver-common entra como reemplazo. Sin esto, el
    # script falla en --all si Hyprland (o cualquier xorg-*) ya esta.
    pac_replace $FALLBACK_PACKAGES
    log "Cinnamon + XLibre instalados."
    log "Disponible como sesion X en el selector de ly."
    warn "Verifica que XLibre quedo activo:"
    warn "  Xorg -version 2>&1 | head -1   (debe decir XLibre, no X.Org)"
}

# =============================================================================
# MODULO APPS (monolitico)
# =============================================================================

module_apps() {
    log "==================== MODULO APPS ===================="
    require_core
    check_network
    detect_user
    confirm "Instalar apps de usuario + theming?" || return

    pac $APPS_PACKAGES
    # shellcheck disable=SC2086
    aur $APPS_AUR

    # Servicios opcionales (no habilitados por defecto, solo avisados)
    log "Apps instaladas."
    warn "Servicios opcionales a habilitar manualmente si los queres:"
    warn "  ufw:        sudo dinitctl enable ufw && sudo ufw enable"
    warn "  power-prof: sudo dinitctl enable power-profiles-daemon"
    warn "  syncthing:  dinitctl --user enable syncthing  (como usuario)"
}

# =============================================================================
# MODULO COSMETICS (GRUB theme + Plymouth)
# =============================================================================
# OPCIONAL y separado a proposito: Plymouth puede colgar el boot con KMS
# Intel. Se mantiene fuera del core para que un problema cosmetico nunca
# bloquee el arranque. Incluye DeviceTimeout para evitar cuelgue indefinido.

module_cosmetics() {
    log "================= MODULO COSMETICS ================="
    require_core
    check_network
    detect_user

    # --- GRUB theme ---
    # artix-grub-theme esta en repos oficiales.
    #
    # IMPORTANTE: nuestro layout tiene /boot SEPARADO (sin encriptar) para
    # habilitar Plymouth. /usr/share/grub/themes/ vive en root, que esta
    # DENTRO del volumen LUKS. GRUB no puede leer ese path porque GRUB no
    # desencripta el disco (lo hace el initramfs despues). La funcion
    # is_path_readable_by_grub() del 00_header detecta esto y descarta el
    # theme silenciosamente, sin warning. Por eso copiamos el theme a
    # /boot/grub/themes/ donde GRUB si puede leerlo.
    #
    # Tambien necesario GRUB_TERMINAL_OUTPUT=gfxterm: sin gfxterm activo,
    # todo el bloque del theme en 00_header se saltea (esta dentro de un
    # 'if [ "x$gfxterm" = x1 ]; then').
    if confirm "Instalar el tema de GRUB de Artix?"; then
        pac artix-grub-theme
        local GRUB_DEFAULT="/etc/default/grub"
        local SRC_THEME="/usr/share/grub/themes/artix"
        local DST_THEME="/boot/grub/themes/artix"
        local THEME_PATH="${DST_THEME}/theme.txt"

        if [[ -d "$SRC_THEME" ]]; then
            mkdir -p /boot/grub/themes
            cp -r "$SRC_THEME" /boot/grub/themes/
            log "Theme copiado a /boot (accesible para GRUB pre-LUKS)."

            backup "$GRUB_DEFAULT"
            # GRUB_THEME apuntando al theme en /boot
            if grep -qE '^#?GRUB_THEME=' "$GRUB_DEFAULT"; then
                sed -i -E "s|^#?GRUB_THEME=.*|GRUB_THEME=\"${THEME_PATH}\"|" "$GRUB_DEFAULT"
            else
                echo "GRUB_THEME=\"${THEME_PATH}\"" >> "$GRUB_DEFAULT"
            fi
            # GRUB_TERMINAL_OUTPUT=gfxterm (sin esto, el theme se saltea)
            if grep -qE '^#?GRUB_TERMINAL_OUTPUT=' "$GRUB_DEFAULT"; then
                sed -i -E 's|^#?GRUB_TERMINAL_OUTPUT=.*|GRUB_TERMINAL_OUTPUT=gfxterm|' "$GRUB_DEFAULT"
            else
                echo "GRUB_TERMINAL_OUTPUT=gfxterm" >> "$GRUB_DEFAULT"
            fi
            grub-mkconfig -o /boot/grub/grub.cfg
            log "Tema de GRUB aplicado desde ${THEME_PATH}"
            warn "Tras 'paru -Syu' que actualice artix-grub-theme, re-copiar:"
            warn "  sudo cp -r ${SRC_THEME} /boot/grub/themes/"
            warn "  sudo grub-mkconfig -o /boot/grub/grub.cfg"
        else
            warn "Directorio del theme no encontrado en $SRC_THEME."
        fi
    fi

    # --- Plymouth: prompt GRAFICO de LUKS (objetivo original del layout) ---
    # Con /boot separado y GRUB_ENABLE_CRYPTODISK desactivado, el desbloqueo
    # de root ocurre en el INITRAMFS (hook encrypt), no en GRUB. Por eso aca
    # Plymouth SI puede capturar el prompt de passphrase y darle feedback
    # visual -- que es lo que Calamares impedia con su layout.
    #
    # CRITICO: el plymouthd del initramfs NO se quita solo en dinit. Sin un
    # servicio que le mande 'quit' al alcanzar login.target, Plymouth se cuelga
    # en el splash y nunca llega a la TTY. Eso lo resuelve 'plymouth-shutdown'
    # del repo AURIS (de capezotte, package maintainer de Artix), que ademas
    # maneja la animacion de apagado. Funciona con o sin display manager porque
    # se apoya en login.target (lo levantan getties y DMs) -> sin punto unico
    # de falla: si ly se rompe, los getties igual disparan el quit.
    #
    # NOTA: el paquete plymouth-shutdown-dinit NO esta publicado de forma
    # confiable en el repo pacman 'auris' (solo el codigo fuente en su Gitea),
    # por eso se instala clonando el repo y copiando los archivos a mano.
    warn "Plymouth dara el prompt GRAFICO de passphrase de LUKS."
    warn "En hardware Intel, sin i915 temprano puede colgar: el modulo lo agrega."
    if confirm "Instalar y configurar Plymouth (prompt grafico de LUKS)?"; then
        pac plymouth

        local PLY_CONF="/etc/plymouth/plymouthd.conf"
        mkdir -p /etc/plymouth
        backup "$PLY_CONF"
        cat > "$PLY_CONF" <<PLYCONF
[Daemon]
Theme=spinner
ShowDelay=0
DeviceTimeout=8
PLYCONF
        log "plymouthd.conf escrito."

        local MKCONF="/etc/mkinitcpio.conf"
        backup "$MKCONF"

        # i915 temprano: CRITICO para Intel. Sin esto el prompt va a texto
        # plano en pantalla negra (la causa del cuelgue en la laptop de test).
        if grep -qE '^MODULES=\(\)' "$MKCONF"; then
            sed -i 's|^MODULES=()|MODULES=(i915)|' "$MKCONF"
        elif ! grep -qE '^MODULES=.*i915' "$MKCONF"; then
            sed -i -E 's|^MODULES=\((.*)\)|MODULES=(i915 \1)|' "$MKCONF"
        fi

        # plymouth despues de udev. encrypt ya esta despues de keyboard, asi
        # que Plymouth captura el prompt de passphrase de root.
        if ! grep -qE '^HOOKS=.*plymouth' "$MKCONF"; then
            sed -i -E 's|^(HOOKS=\(base udev) |\1 plymouth |' "$MKCONF"
        fi

        # Parametros de kernel: splash + ocultar cursor + fastboot Intel
        local GRUB_DEFAULT="/etc/default/grub"
        backup "$GRUB_DEFAULT"
        if ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*splash' "$GRUB_DEFAULT"; then
            sed -i -E 's|^(GRUB_CMDLINE_LINUX_DEFAULT="quiet)|\1 splash vt.global_cursor_default=0 i915.fastboot=1|' "$GRUB_DEFAULT"
        fi

        # --- plymouth-shutdown desde AURIS (resuelve el cuelgue del splash) ---
        # Se clona el repo de codigo fuente y se copian los archivos a mano,
        # como usuario real (git) y luego copia con permisos root.
        local PS_REPO="https://auris.artixlinux.org/auris/plymouth-shutdown-dinit.git"
        local PS_TMP
        PS_TMP="$(sudo -u "$REAL_USER" mktemp -d)"
        if sudo -u "$REAL_USER" git clone "$PS_REPO" "$PS_TMP/plymouth-shutdown-dinit"; then
            local PS_SRC="$PS_TMP/plymouth-shutdown-dinit"
            # El script real (.script) va a /usr/lib/dinit/ como ejecutable
            install -Dm755 "$PS_SRC/plymouth-shutdown.script" /usr/lib/dinit/plymouth-shutdown
            # Los archivos de servicio van a /etc/dinit.d/
            install -Dm644 "$PS_SRC/plymouth-wait" /etc/dinit.d/plymouth-wait
            install -Dm644 "$PS_SRC/plymouth-shutdown" /etc/dinit.d/plymouth-shutdown
            # La config a /etc/dinit.d/config/
            install -Dm644 "$PS_SRC/plymouth-shutdown.conf" /etc/dinit.d/config/plymouth-shutdown.conf
            # Habilitar los servicios (symlink en boot.d)
            ln -sf /etc/dinit.d/plymouth-wait /etc/dinit.d/boot.d/plymouth-wait
            ln -sf /etc/dinit.d/plymouth-shutdown /etc/dinit.d/boot.d/plymouth-shutdown
            rm -rf "$PS_TMP"
            log "plymouth-shutdown instalado y habilitado (boot-quit + shutdown anim)."
        else
            rm -rf "$PS_TMP"
            warn "No se pudo clonar plymouth-shutdown desde AURIS."
            warn "Plymouth se va a COLGAR en el splash sin este servicio."
            warn "Instalalo a mano: clona $PS_REPO y copia los archivos."
        fi

        mkinitcpio -P
        grub-mkconfig -o /boot/grub/grub.cfg

        log "Plymouth configurado para el prompt grafico de LUKS."
        warn "Boot esperado: GRUB -> Plymouth con prompt de passphrase grafico"
        warn "  -> animacion (BOOT_SLEEP) -> al llegar a login.target,"
        warn "  plymouth-shutdown manda 'quit' -> login limpio en TTY."
        warn "Ajusta BOOT_SLEEP/SHUTDOWN_SLEEP en"
        warn "  /etc/dinit.d/config/plymouth-shutdown.conf si queres."
        warn "Si el prompt aparece en texto plano sobre pantalla negra: el i915"
        warn "  no cargo a tiempo. Igual podes tipear la passphrase a ciegas."
        warn "Si se cuelga del todo: por SSH/TTY quita 'plymouth' de HOOKS en"
        warn "  $MKCONF y 'mkinitcpio -P'. El sistema arranca sin Plymouth."
    fi
}



usage() {
    cat <<USAGE
Uso: sudo $0 [--core|--fallback|--hyprland|--apps|--cosmetics|--all]

  --core       paru + ly (skin matrix) + sesion base. Correr PRIMERO.
  --fallback   Cinnamon + XLibre como respaldo (requiere core).
               Instalar ANTES de --hyprland para evitar conflictos
               xlibre-xserver-common vs xorg-server-common.
  --hyprland   Stack Hyprland (requiere core; idealmente despues de fallback).
  --apps       Apps de usuario + theming (requiere core).
  --cosmetics  Tema de GRUB + Plymouth opcional (requiere core).
  --all        core -> fallback -> hyprland -> apps -> cosmetics, en orden.

Dotfiles fuera de scope: traelos a mano. Esto solo instala paquetes.
USAGE
}

main() {
    require_root
    detect_user      # debe correr antes de sudo_extend para tener $REAL_USER
    sudo_extend
    [[ $# -gt 0 ]] || { usage; exit 1; }

    case "$1" in
        --core)     module_core ;;
        --hyprland) module_hyprland ;;
        --fallback) module_fallback ;;
        --apps)     module_apps ;;
        --cosmetics) module_cosmetics ;;
        --all)
            # ORDEN CRITICO: fallback ANTES de hyprland.
            # XLibre debe instalarse primero para que xlibre-xserver-common
            # quede como el 'common' del sistema. Si Hyprland va primero,
            # trae xorg-xwayland que arrastra xorg-server-common, y despues
            # XLibre conflictua sin resolucion limpia.
            module_core
            module_fallback
            module_hyprland
            module_apps
            module_cosmetics
            ;;
        -h|--help)  usage ;;
        *)          err "Opcion desconocida: $1"; usage; exit 1 ;;
    esac

    echo
    log "===================== LISTO ====================="
    echo "  Reinicia o reinicia ly para ver los cambios de sesion."
    echo "  En el selector de ly podras elegir Hyprland o Cinnamon."
}

main "$@"
