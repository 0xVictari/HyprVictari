#!/usr/bin/env bash
#
# suckless-setup.sh
#
# Arma la sesión X11 con dwm (victariwm) + slstatus + sxhkd en Mint/Debian/Ubuntu
# o Arch/CachyOS. Corre como TU usuario (los builds no deben correr como root;
# usa sudo solo para instalar).
#
# USO (desde el repo clonado en ~/HyprVictari):
#   ./install/suckless-setup.sh --deps      # paquetes de build y de la sesión
#   ./install/suckless-setup.sh --fonts     # GoMono Nerd Font
#   ./install/suckless-setup.sh --build     # submódulos + build/install de dwm y slstatus
#   ./install/suckless-setup.sh --system    # sesión dwm en el login + wrapper de brillo
#   ./install/suckless-setup.sh --dotfiles  # stow dwm sxhkd clipboard ohmyposh zsh
#   ./install/suckless-setup.sh --all       # todo, en ese orden
#
# Idempotente: se puede correr más de una vez.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
STOW_PKGS="dwm sxhkd clipboard ohmyposh zsh"

# =============================================================================
# PAQUETES POR FAMILIA (editar acá; PACKAGES.md los documenta)
# =============================================================================

# Build de dwm/slstatus + herramientas que usan los build scripts
DEB_BUILD="build-essential git pkg-config patch rsync \
libx11-dev libxft-dev libxinerama-dev libfreetype-dev libfontconfig-dev"
ARCH_BUILD="base-devel git pkgconf patch rsync \
libx11 libxft libxinerama freetype2 fontconfig"

# Sesión: autostart.sh, config.h, sxhkdrc, slstatus, clipboard
DEB_SESSION="xorg x11-xserver-utils xclip \
feh sxhkd picom xautolock cinnamon-screensaver policykit-1-gnome \
suckless-tools rofi kitty btop flameshot nemo \
wireless-tools wireplumber brightnessctl python3 \
stow zsh eza tree fastfetch"
ARCH_SESSION="xorg-server xorg-xinit xorg-xauth xorg-xrandr xclip \
feh sxhkd picom xautolock cinnamon-screensaver polkit-gnome \
dmenu rofi kitty btop flameshot nemo \
wireless_tools wireplumber brightnessctl python \
stow zsh eza tree fastfetch"

NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Go-Mono.tar.xz"

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

FAMILY=""
detect_family() {
    local id="" like=""
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"; like="${ID_LIKE:-}"
    case " $id $like " in
        *" arch "*|*" cachyos "*) FAMILY=arch ;;
        *" debian "*|*" ubuntu "*|*" linuxmint "*) FAMILY=debian ;;
        *) die "Distro no soportada ($id). Solo Debian/Ubuntu/Mint o Arch/CachyOS." ;;
    esac
    log "Distro: ${PRETTY_NAME:-$id} -> familia $FAMILY"
}

# Arch: lo que está en los repos va por pacman, el resto por paru (AUR).
arch_install() {
    local -a repo=() aur=()
    local p
    for p in "$@"; do
        if pacman -Si "$p" >/dev/null 2>&1 || pacman -Sg "$p" >/dev/null 2>&1; then
            repo+=("$p")
        else
            aur+=("$p")
        fi
    done
    (( ${#repo[@]} )) && sudo pacman -S --needed --noconfirm "${repo[@]}"
    if (( ${#aur[@]} )); then
        command -v paru >/dev/null 2>&1 || die "Faltan paquetes de AUR (${aur[*]}) y no hay paru."
        paru -S --needed --noconfirm "${aur[@]}"
    fi
}

pkg_install() {
    if [[ "$FAMILY" == debian ]]; then
        sudo apt-get install -y "$@"
    else
        arch_install "$@"
    fi
}

# =============================================================================
# MÓDULOS
# =============================================================================

module_deps() {
    log "================ DEPENDENCIAS ================"
    confirm "Instalar paquetes de build y de la sesión X11?" || return 0
    if [[ "$FAMILY" == debian ]]; then
        sudo apt-get update
        # shellcheck disable=SC2086
        pkg_install $DEB_BUILD $DEB_SESSION
    else
        # shellcheck disable=SC2086
        pkg_install $ARCH_BUILD $ARCH_SESSION
    fi
    log "Dependencias listas."
}

module_fonts() {
    log "=================== FUENTES ==================="
    if fc-list | grep -qi 'GoMono Nerd Font'; then
        log "GoMono Nerd Font ya está instalada."
        return 0
    fi
    confirm "Instalar GoMono Nerd Font?" || return 0
    if [[ "$FAMILY" == arch ]]; then
        pkg_install ttf-go-nerd
    else
        # Sin paquete apt: release oficial de nerd-fonts en ~/.local/share/fonts
        local dir="$HOME/.local/share/fonts/GoMonoNerd" tmp
        tmp="$(mktemp -d)"
        curl -fL --retry 3 -o "$tmp/Go-Mono.tar.xz" "$NERD_FONT_URL"
        mkdir -p "$dir"
        tar -xJf "$tmp/Go-Mono.tar.xz" -C "$dir"
        rm -rf "$tmp"
        fc-cache -f "$dir"
    fi
    log "Fuente instalada."
}

module_build() {
    log "==================== BUILD ===================="
    confirm "Inicializar submódulos y compilar/instalar victariwm + slstatus?" || return 0
    git -C "$REPO" submodule update --init --recursive
    (cd "$REPO/suckless" && ./build-victariwm.sh --install)
    (cd "$REPO/suckless" && ./build-slstatus.sh --install)
    log "dwm y slstatus instalados en /usr/local/bin."
}

module_system() {
    log "=================== SISTEMA ==================="
    confirm "Registrar la sesión dwm y el wrapper de brillo (sudo)?" || return 0

    # Entrada en el selector del login (ly, LightDM, etc.)
    local xs=/usr/share/xsessions/dwm.desktop
    if [[ ! -f "$xs" ]]; then
        sudo install -Dm644 /dev/stdin "$xs" <<'DESKTOP'
[Desktop Entry]
Name=dwm
Comment=Dynamic window manager (victariwm)
Exec=dwm
Type=XSession
DESKTOP
        log "Sesión registrada: $xs"
    else
        log "La sesión dwm ya existe ($xs)."
    fi

    # config.h usa 'sudo brightness-control set 5%+'
    sudo install -Dm755 /dev/stdin /usr/local/bin/brightness-control <<'BRIGHT'
#!/bin/bash
brightnessctl "$@"
BRIGHT
    local rule="/etc/sudoers.d/brightness" tmp
    tmp="$(mktemp)"
    printf '%s ALL=(ALL) NOPASSWD: /usr/local/bin/brightness-control\n' "$USER" > "$tmp"
    if sudo visudo -cf "$tmp" >/dev/null; then
        sudo install -m440 "$tmp" "$rule"
        log "Brillo: /usr/local/bin/brightness-control + regla en $rule"
    else
        warn "La regla de sudoers no validó; no se instaló."
    fi
    rm -f "$tmp"
}

# picom trae /etc/xdg/autostart/picom.desktop sin limitar el escritorio, así que
# Cinnamon (u otro) lo lanzaría encima de su propio compositor. dwm lo arranca
# desde ~/.dwm/autostart.sh y Hyprland no lee el autostart XDG: se oculta solo
# para este usuario. Si el archivo ya existe, se respeta.
hide_picom_autostart() {
    local dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
    [[ -f /etc/xdg/autostart/picom.desktop && ! -e "$dir/picom.desktop" ]] || return 0
    mkdir -p "$dir"
    printf '[Desktop Entry]\nType=Application\nName=Picom\nHidden=true\n' > "$dir/picom.desktop"
    log "picom oculto del autostart XDG (lo arranca dwm)."
}

module_dotfiles() {
    log "=================== DOTFILES ==================="
    confirm "Aplicar stow de: $STOW_PKGS?" || return 0
    # Directorios reales para que stow no los pliegue en un symlink al repo
    mkdir -p "$HOME/.config/zsh" "$HOME/.config/systemd/user" "$HOME/.local/bin"

    local pkg conflicts
    for pkg in $STOW_PKGS; do
        conflicts="$(stow -n -d "$REPO" -t "$HOME" "$pkg" 2>&1 | grep -E 'existing target|cannot stow' || true)"
        if [[ -n "$conflicts" ]]; then
            warn "stow $pkg tiene conflictos, lo salteo. Movelos a mano y volvé a correr:"
            printf '    %s\n' "$conflicts"
            continue
        fi
        stow -d "$REPO" -t "$HOME" -R "$pkg" 2>&1 | grep -v 'BUG in' || true
        log "stow $pkg"
    done

    systemctl --user daemon-reload || true
    log "clip-normalize lo arranca ~/.dwm/autostart.sh al iniciar dwm."

    hide_picom_autostart

    if [[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/dwm/monitors.local" ]]; then
        log "Monitores: modo preferido de cada pantalla y la externa arriba. Para"
        log "  fijar otra cosa, ~/.config/dwm/monitors.local (ver ~/.dwm/monitor-setup.sh)."
    fi

    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != */zsh ]] && command -v zsh >/dev/null; then
        chsh -s "$(command -v zsh)"
        log "Shell -> zsh (vale desde el próximo login)."
    fi
}

# =============================================================================
# MAIN
# =============================================================================

usage() {
    cat <<USAGE
Uso: $0 [--deps|--fonts|--build|--system|--dotfiles|--all]

  --deps       Paquetes de build y de la sesión (apt o pacman/paru).
  --fonts      GoMono Nerd Font (pacman en Arch; release de nerd-fonts en Debian).
  --build      Submódulos + build-victariwm.sh/build-slstatus.sh --install.
  --system     /usr/share/xsessions/dwm.desktop + brightness-control y su regla sudo.
  --dotfiles   stow de: $STOW_PKGS (saltea paquetes con conflictos).
  --all        deps -> fonts -> build -> system -> dotfiles.

Correr como usuario normal: pide sudo cuando hace falta.
Fuera de alcance: Brave, Slack, Citrix Workspace (paquetes de cada vendor).
USAGE
}

main() {
    [[ $# -gt 0 ]] || { usage; exit 1; }
    [[ "$1" == -h || "$1" == --help ]] && { usage; exit 0; }
    [[ "$(id -u)" -ne 0 ]] || die "No correr como root: los builds van como usuario (usa sudo adentro)."
    [[ -d "$REPO/suckless" ]] || die "No encuentro $REPO/suckless; correlo desde el repo."
    detect_family

    case "$1" in
        --deps)     module_deps ;;
        --fonts)    module_fonts ;;
        --build)    module_build ;;
        --system)   module_system ;;
        --dotfiles) module_dotfiles ;;
        --all)
            module_deps
            module_fonts
            module_build
            module_system
            module_dotfiles
            ;;
        *) err "Opción desconocida: $1"; usage; exit 1 ;;
    esac
    log "Listo. Cerrá sesión y elegí dwm en el login."
}

main "$@"
