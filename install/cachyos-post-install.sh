#!/usr/bin/env bash
#
# cachyos-post-install.sh
#
# Post-instalación del Desktop sobre CachyOS (systemd). La base (particionado,
# LUKS, btrfs, bootloader, Plymouth) la hace el instalador oficial: ver
# install/README.md. Este script instala paquetes, habilita ly y despliega los
# dotfiles con stow.
#
# USO:
#   sudo ./cachyos-post-install.sh --core       # paru + sesión base + ly. PRIMERO.
#   sudo ./cachyos-post-install.sh --cinnamon   # Cinnamon (Xorg) + Nemo/Xapps
#   sudo ./cachyos-post-install.sh --hyprland   # stack Hyprland
#   sudo ./cachyos-post-install.sh --apps       # apps de usuario + theming
#   sudo ./cachyos-post-install.sh --dotfiles   # clonar HyprVictari + stow + Zap
#   sudo ./cachyos-post-install.sh --all        # todo lo anterior, en ese orden
#   sudo ./cachyos-post-install.sh --gaming     # juegos/emuladores (aparte: no entra en --all)
#
# Idempotente: pacman/paru con --needed, la config se reescribe solo si cambia
# y los archivos que se pisan quedan respaldados.

set -euo pipefail

# =============================================================================
# LISTAS DE PAQUETES (editar acá; PACKAGES.md las documenta)
# =============================================================================

# --- Core (repos oficiales / CachyOS) ---
CORE_PACKAGES="base-devel git \
pipewire pipewire-pulse pipewire-alsa wireplumber \
gst-plugin-pipewire alsa-utils pavucontrol \
polkit polkit-gnome gnome-keyring \
xdg-user-dirs xdg-utils \
brightnessctl \
bluez bluez-utils blueman \
ly"

# --- Cinnamon: sesión de respaldo sobre Xorg + Nemo y las Xapps ---
# xorg-xauth: ly lo necesita para arrancar sesiones X.
# ghostty: terminal de Cinnamon (en Hyprland sigue kitty).
CINNAMON_PACKAGES="cinnamon \
xorg-server xorg-xauth xorg-xinit \
nemo xed xreader xviewer \
ghostty"
CINNAMON_AUR="nemo-fileroller"

# --- Hyprland (lo que usan hypr/, waybar/ y wofi/) ---
HYPRLAND_PACKAGES="hyprland hypridle hyprlock hyprpaper hyprsunset \
xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
qt5-wayland qt6-wayland \
wofi dunst \
cava playerctl libnotify \
kitty \
grim slurp wl-clipboard flameshot imagemagick \
ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-go-nerd \
ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono \
noto-fonts noto-fonts-cjk noto-fonts-emoji \
ttf-liberation ttf-dejavu"
# waybar-git y no el waybar de los repos: resultó más estable.
HYPRLAND_AUR="icat waybar-git"

# --- Apps de usuario + theming ---
APPS_PACKAGES="zsh zsh-completions neovim zed \
mpv vlc \
signal-desktop telegram-desktop \
discord element-desktop obsidian qbittorrent \
libreoffice-still \
gthumb syncthing yt-dlp \
btop ripgrep ncdu duf pv tree \
unrar unzip rsync wget eza \
fastfetch \
papirus-icon-theme \
nwg-look \
power-profiles-daemon ufw \
stow"
# Ojo: el "zap-git" del AUR NO es Zap (zsh), es issmirnov/zap (atajos web).
# Zap se clona en el módulo --dotfiles.
APPS_AUR="brave-bin oh-my-posh-bin \
qogir-gtk-theme qogir-icon-theme qogir-cursor-theme \
chicago95-theme"

# --- Gaming (módulo aparte, no entra en --all) ---
# cachyos-gaming-meta: wine, proton, umu, winetricks y libs lib32 (sin Steam).
GAMING_PACKAGES="cachyos-gaming-meta openmw"
GAMING_AUR="melonds-bin nugget-doom"
# doom-infinite (0.98 PP2) solo anda con GZDoom 4.10.0: su README pide ">= 4.8.2",
# pero con versiones nuevas falla. Se usa el portable oficial, aparte del
# sistema, en ~/doomwads (ahí van también DOOM2.WAD, el .pk3 y doom-infinite.sh,
# a mano). No hay GZDoom/UZDoom del sistema: no se usa para nada más.
GZDOOM_PORTABLE_URL="https://github.com/ZDoom/gzdoom/releases/download/g4.10.0/GZDoom.v4.10.0.LinuxPortable.tar.xz"
GZDOOM_PORTABLE_SHA256="4c3a3753b187676e9acc3e807bd4e860ba048358779944427e3c44ed6912a815"
GZDOOM_PORTABLE_DIR="GZDoom.v4.10.0.LinuxPortable"   # carpeta que trae el tarball

# --- Dotfiles ---
DOTFILES_REPO="https://github.com/0xVictari/HyprVictari.git"
DOTFILES_PUSH="git@github.com:0xVictari/HyprVictari.git"
DOTFILES_STOW="zsh ohmyposh hyprland waybar wofi dunst kitty ghostty zed fastfetch"

# Zap (gestor de plugins de zsh): clon directo, como dice zsh/.zshrc. El
# install.zsh oficial reescribe ~/.zshrc, y el paquete zap-git es otro programa.
ZAP_REPO="https://github.com/zap-zsh/zap"
ZAP_BRANCH="release-v1"

# Paquetes de CachyOS que traen su propia config de Hyprland y chocan con stow
CACHYOS_HYPR_SETTINGS="cachyos-hyprland-settings"

# =============================================================================
# HELPERS
# =============================================================================

log()  { printf '\033[1;32m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

confirm() {
    local answer
    printf '\033[1;33m%s [y/N]:\033[0m ' "$1"
    read -r answer
    [[ "$answer" =~ ^[yY]$ ]]
}

require_root() { [[ "$(id -u)" -eq 0 ]] || die "Correr como root (sudo)."; }

REAL_USER="${SUDO_USER:-}"
REAL_HOME=""
detect_user() {
    [[ -n "$REAL_USER" && "$REAL_USER" != root ]] || die "No se detectó \$SUDO_USER. Correr con: sudo $0 ..."
    REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
    [[ -n "$REAL_HOME" ]] || die "No se pudo determinar el home de $REAL_USER."
}

check_cachyos() {
    grep -qi '^ID=cachyos' /etc/os-release 2>/dev/null \
        || warn "Esto no parece CachyOS (/etc/os-release). Sigo, pero los nombres de paquetes asumen sus repos."
}

check_network() {
    ping -c1 -W3 1.1.1.1 >/dev/null 2>&1 || die "Sin conexión a internet."
}

as_user() { sudo -u "$REAL_USER" HOME="$REAL_HOME" "$@"; }

# Las listas se pasan sin comillas a propósito (word splitting).
pac() { pacman -S --needed --noconfirm "$@"; }
aur() { as_user paru -S --needed --noconfirm "$@"; }

TS="$(date +%Y%m%d-%H%M%S)"
backup() { [[ -f "$1" ]] && cp -a "$1" "${1}.bak-${TS}" && log "Backup: ${1}.bak-${TS}" || true; }

# --- sudo sin cortes durante la corrida ---
# paru corre como el usuario real y vuelve a pedir sudo para instalar; sin
# esto, los builds de AUR largos frenan pidiendo password. Drop-in temporal,
# se borra al salir (incluso si el script falla).
SUDO_DROPIN="/etc/sudoers.d/99-postinstall-temp"
sudo_extend() {
    [[ -f "$SUDO_DROPIN" ]] && return
    # El trap va recién acá: sin root (ej. --help) no hay nada que borrar.
    trap sudo_restore EXIT INT TERM
    printf 'Defaults timestamp_timeout=120\n%s ALL=(ALL) NOPASSWD: ALL\n' "$REAL_USER" > "$SUDO_DROPIN"
    chmod 440 "$SUDO_DROPIN"
    visudo -cf "$SUDO_DROPIN" >/dev/null || { rm -f "$SUDO_DROPIN"; die "Drop-in de sudoers inválido."; }
}
sudo_restore() { rm -f "$SUDO_DROPIN"; }

# =============================================================================
# CORE: paru + sesión base + ly
# =============================================================================

install_paru() {
    command -v paru >/dev/null 2>&1 && { log "paru ya está instalado."; return; }
    # CachyOS lo publica en sus repos; si no, build desde AUR.
    if pacman -Si paru >/dev/null 2>&1; then
        pac paru
    else
        log "paru no está en los repos: build desde AUR..."
        as_user bash -c '
            set -e
            tmp="$(mktemp -d)"; cd "$tmp"
            git clone https://aur.archlinux.org/paru-bin.git
            cd paru-bin && makepkg -si --noconfirm
            cd / && rm -rf "$tmp"
        '
    fi
    command -v paru >/dev/null 2>&1 || die "Falló la instalación de paru."
}

setup_ly() {
    # Un solo display manager: deshabilitar los que pueda haber dejado el instalador.
    local dm
    for dm in sddm gdm lightdm lxdm plasmalogin greetd; do
        if systemctl is-enabled "${dm}.service" >/dev/null 2>&1; then
            systemctl disable "${dm}.service"
            log "Deshabilitado ${dm}."
        fi
    done

    # ly >= 1.1 usa una unit por TTY (ly@tty2); las versiones viejas, ly.service.
    if systemctl list-unit-files 'ly@.service' --no-legend 2>/dev/null | grep -q .; then
        # ly toma tty2: no debe haber un getty compitiendo por esa TTY.
        systemctl disable getty@tty2.service >/dev/null 2>&1 || true
        systemctl enable ly@tty2.service
        log "ly habilitado en tty2 (ly@tty2.service)."
    else
        systemctl enable ly.service
        log "ly habilitado (ly.service)."
    fi

    local conf=/etc/ly/config.ini
    if [[ -f "$conf" ]]; then
        if ! grep -qE '^animation\s*=\s*matrix' "$conf"; then
            backup "$conf"
            sed -i -E '/^#?\s*animation\s*=/d' "$conf"
            echo "animation = matrix" >> "$conf"
            log "ly: animación matrix."
        fi
    else
        warn "$conf no existe; no se configuró la animación."
    fi
}

module_core() {
    log "==================== CORE ===================="
    confirm "Instalar core (paru + sesión base + ly)?" || return 0
    pac $CORE_PACKAGES
    install_paru
    setup_ly
    systemctl enable bluetooth.service
    touch /var/lib/.cachyos-post-core-done
    log "Core listo. pipewire/wireplumber arrancan solos como user services de systemd."
}

require_core() {
    [[ -f /var/lib/.cachyos-post-core-done ]] || die "Correr primero --core."
}

# =============================================================================
# CINNAMON (sesión de respaldo, Xorg)
# =============================================================================

module_cinnamon() {
    log "=================== CINNAMON ==================="
    require_core
    confirm "Instalar Cinnamon + Nemo/Xapps?" || return 0
    pac $CINNAMON_PACKAGES
    aur $CINNAMON_AUR
    set_cinnamon_terminal
    log "Cinnamon instalado: aparece como sesión X en ly."
}

# Terminal por defecto de Cinnamon (Ctrl+Alt+T, "Abrir en terminal" de Nemo):
# ghostty. Va como default del sistema (override de gschema); un valor que el
# usuario ya haya elegido en dconf manda sobre esto.
set_cinnamon_terminal() {
    local dir=/usr/share/glib-2.0/schemas
    local file="$dir/90_hyprvictari.gschema.override"
    local want="[org.cinnamon.desktop.default-applications.terminal]
exec='ghostty'
exec-arg='-e'"
    [[ -f "$file" && "$(<"$file")" == "$want" ]] && return
    printf '%s\n' "$want" > "$file"
    glib-compile-schemas "$dir"
    log "Cinnamon: terminal por defecto -> ghostty."
}

# =============================================================================
# HYPRLAND
# =============================================================================

module_hyprland() {
    log "=================== HYPRLAND ==================="
    require_core
    confirm "Instalar el stack de Hyprland?" || return 0

    if pacman -Q "$CACHYOS_HYPR_SETTINGS" >/dev/null 2>&1; then
        warn "$CACHYOS_HYPR_SETTINGS está instalado: trae su propia config de Hyprland/Waybar y choca con los dotfiles."
        if confirm "Desinstalarlo?"; then
            pacman -Rns --noconfirm "$CACHYOS_HYPR_SETTINGS"
        fi
    fi

    # El waybar de los repos (lo puede traer la edición Hyprland de CachyOS)
    # choca con waybar-git y, con --noconfirm, pacman no acepta reemplazarlo:
    # aborta. Se saca antes. "pacman -Qq waybar" devuelve waybar-git si ese es
    # el instalado (lo provee), así que esto solo toca el de los repos.
    if [[ "$(pacman -Qq waybar 2>/dev/null)" == waybar ]]; then
        warn "Saco el waybar de los repos para instalar waybar-git."
        pacman -Rdd --noconfirm waybar
    fi

    pac $HYPRLAND_PACKAGES
    aur $HYPRLAND_AUR
    log "Hyprland instalado. Config: módulo --dotfiles."
}

# =============================================================================
# APPS
# =============================================================================

module_apps() {
    log "===================== APPS ====================="
    require_core
    confirm "Instalar apps de usuario + theming?" || return 0
    pac $APPS_PACKAGES
    aur $APPS_AUR
    log "Apps instaladas."
    warn "Servicios opcionales (no se habilitan solos):"
    warn "  ufw:        sudo systemctl enable --now ufw && sudo ufw enable"
    warn "  power-prof: sudo systemctl enable --now power-profiles-daemon"
    warn "  syncthing:  systemctl --user enable --now syncthing   (como usuario)"
}

# =============================================================================
# GAMING (no entra en --all)
# =============================================================================

# GZDoom 4.10.0 portable en ~/doomwads, solo para doom-infinite (ver arriba).
install_gzdoom_portable() {
    local dir="$REAL_HOME/doomwads" tmp
    if [[ -x "$dir/$GZDOOM_PORTABLE_DIR/gzdoom" ]]; then
        log "GZDoom 4.10.0 portable ya está en ~/doomwads."
        return
    fi
    tmp="$(as_user mktemp -d)"   # del usuario: tar corre como él
    as_user curl -fL --retry 3 -o "$tmp/gzdoom.tar.xz" "$GZDOOM_PORTABLE_URL" \
        || { rm -rf "$tmp"; warn "No se pudo bajar GZDoom 4.10.0; lo salteo."; return; }
    if ! echo "$GZDOOM_PORTABLE_SHA256  $tmp/gzdoom.tar.xz" | sha256sum -c --quiet; then
        rm -rf "$tmp"
        warn "GZDoom 4.10.0: el checksum no coincide; no lo instalo."
        return
    fi
    as_user mkdir -p "$dir"
    as_user tar -xJf "$tmp/gzdoom.tar.xz" -C "$dir"
    rm -rf "$tmp"
    log "GZDoom 4.10.0 portable en ~/doomwads/$GZDOOM_PORTABLE_DIR."
    warn "doom-infinite: DOOM2.WAD, el .pk3 y doom-infinite.sh van a mano en ~/doomwads."
}

module_gaming() {
    log "==================== GAMING ===================="
    require_core
    confirm "Instalar gaming (cachyos-gaming-meta, openmw, melonDS, Nugget Doom, GZDoom 4.10 portable)?" || return 0
    pac $GAMING_PACKAGES
    aur $GAMING_AUR
    install_gzdoom_portable
    log "Gaming listo."
}

# =============================================================================
# DOTFILES (clone + stow)
# =============================================================================

# Symlink que stow reconoce como propio: relativo y resolviendo dentro del repo
# (incluye directorios plegados, ej. ~/.config/hypr -> ../HyprVictari/...).
stow_owned() {
    local link="$1" repo="$2"
    [[ "$(readlink "$link")" != /* && "$(readlink -f "$link")" == "$repo/"* ]]
}

# Mueve a $bdir todo lo que haría fallar a stow. Para cada archivo de cada
# paquete recorre la ruta en $HOME componente por componente:
#   - symlink propio de stow       -> ya está bien, siguiente archivo
#   - cualquier otro symlink        -> se respalda el LINK (nunca lo que apunta)
#   - archivo real al final         -> se respalda
#   - componente inexistente        -> nada que hacer
# Así no depende de parsear los mensajes de stow.
dotfiles_backup_conflicts() {
    local repo="$1" bdir="$2" pkg f rel p comp sub
    local -a parts
    for pkg in $DOTFILES_STOW; do
        [[ -d "$repo/$pkg" ]] || { warn "Paquete $pkg no existe en el repo; lo salteo."; continue; }
        while IFS= read -r -d '' f; do
            rel="${f#"$repo/$pkg/"}"
            IFS=/ read -ra parts <<< "$rel"
            p="$REAL_HOME"
            for comp in "${parts[@]}"; do
                p="$p/$comp"
                if [[ -L "$p" ]]; then
                    stow_owned "$p" "$repo" && break
                elif [[ ! -e "$p" ]]; then
                    break
                elif [[ -d "$p" && "$p" != "$REAL_HOME/$rel" ]]; then
                    continue   # directorio real intermedio: stow entra en él
                fi
                sub="${p#"$REAL_HOME/"}"
                as_user mkdir -p "$bdir/$(dirname "$sub")"
                mv "$p" "$bdir/$sub"
                log "Respaldado: ~/$sub"
                break
            done
        done < <(find "$repo/$pkg" \( -type f -o -type l \) -print0)
    done
}

# Zap en ~/.local/share/zap, donde lo busca zsh/.zshrc. Los plugins (plug ...)
# los clona el primer zsh interactivo.
install_zap() {
    local dir="$REAL_HOME/.local/share/zap"
    if pacman -Q zap-git >/dev/null 2>&1; then
        warn "zap-git está instalado y NO es Zap de zsh (es issmirnov/zap, atajos web): pacman -Rns zap-git"
    fi
    if [[ -f "$dir/zap.zsh" ]]; then
        log "Zap ya está en ~/.local/share/zap."
        return
    fi
    if [[ -e "$dir" ]]; then
        warn "~/.local/share/zap existe pero no tiene zap.zsh; no lo toco."
        return
    fi
    as_user mkdir -p "$REAL_HOME/.local/share"
    as_user git clone --depth 1 -b "$ZAP_BRANCH" "$ZAP_REPO" "$dir"
    log "Zap clonado en ~/.local/share/zap (los plugins se bajan al abrir zsh)."
}

module_dotfiles() {
    log "=================== DOTFILES ==================="
    confirm "Clonar HyprVictari y aplicar stow ($DOTFILES_STOW)?" || return 0
    command -v stow >/dev/null 2>&1 || pac stow
    command -v git  >/dev/null 2>&1 || pac git

    local repo="$REAL_HOME/HyprVictari"
    if [[ -d "$repo/.git" ]]; then
        log "El repo ya existe en $repo: git pull."
        as_user git -C "$repo" pull --ff-only || warn "git pull falló; sigo con lo que hay."
    else
        as_user git clone "$DOTFILES_REPO" "$repo"
        # Clon por HTTPS (sin llave SSH todavía); el push va por SSH.
        as_user git -C "$repo" remote set-url --push origin "$DOTFILES_PUSH"
    fi

    # Directorios que deben existir como reales para que stow no los "pliegue"
    # en un symlink al repo (lo que escribieran otras herramientas iría al repo).
    # kitty: theme-switch.sh deja ahí current-theme.conf y, si la carpeta
    # apunta al repo, no la toca (kitty no cambiaría de theme nunca).
    as_user mkdir -p "$REAL_HOME/.config/zsh" "$REAL_HOME/.config/kitty"

    local bdir="$REAL_HOME/.dotfiles-backup-$TS"
    dotfiles_backup_conflicts "$repo" "$bdir"
    if [[ -d "$bdir" ]]; then
        warn "Lo que había quedó en $bdir"
    fi

    as_user stow -d "$repo" -t "$REAL_HOME" -R $DOTFILES_STOW
    log "Stow aplicado: $DOTFILES_STOW"

    install_zap

    local zsh_path
    zsh_path="$(command -v zsh || true)"
    if [[ -n "$zsh_path" && "$(getent passwd "$REAL_USER" | cut -d: -f7)" != "$zsh_path" ]]; then
        chsh -s "$zsh_path" "$REAL_USER"
        log "Shell de $REAL_USER -> zsh."
    fi
    [[ -n "$zsh_path" ]] || warn "zsh no está instalado (módulo --apps)."
}

# =============================================================================
# MAIN
# =============================================================================

usage() {
    cat <<USAGE
Uso: sudo $0 [--core|--cinnamon|--hyprland|--apps|--dotfiles|--all|--gaming]

  --core       paru + sesión base (pipewire, polkit, keyring, bluetooth) + ly. PRIMERO.
  --cinnamon   Cinnamon sobre Xorg + Nemo, Xapps y ghostty (sesión de respaldo).
  --hyprland   Stack Hyprland (lo que usan hypr/, waybar/, wofi/).
  --apps       Apps de usuario, theming, zsh/oh-my-posh.
  --dotfiles   Clona HyprVictari en ~/HyprVictari, hace stow (con backup) y clona Zap.
  --all        core -> cinnamon -> hyprland -> apps -> dotfiles.
  --gaming     cachyos-gaming-meta, openmw, melonDS, Nugget Doom y GZDoom 4.10
               portable para doom-infinite. No entra en --all.

La instalación base la hace el instalador de CachyOS: ver install/README.md.
USAGE
}

main() {
    [[ $# -gt 0 ]] || { usage; exit 1; }
    [[ "$1" == -h || "$1" == --help ]] && { usage; exit 0; }

    require_root
    detect_user
    check_cachyos
    check_network
    sudo_extend

    case "$1" in
        --core)     module_core ;;
        --cinnamon) module_cinnamon ;;
        --hyprland) module_hyprland ;;
        --apps)     module_apps ;;
        --dotfiles) module_dotfiles ;;
        --gaming)   module_gaming ;;
        --all)
            module_core
            module_cinnamon
            module_hyprland
            module_apps
            module_dotfiles
            ;;
        *) err "Opción desconocida: $1"; usage; exit 1 ;;
    esac

    echo
    log "===================== LISTO ====================="
    echo "  Reiniciá: en ly vas a poder elegir Hyprland o Cinnamon."
}

main "$@"
