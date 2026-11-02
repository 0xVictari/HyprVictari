# Inventario de paquetes

Lo que usan los configs de este repo, separado por máquina. Los nombres para
Arch valen para CachyOS, que es la base prevista para el Desktop.
`artix-*.sh` está deprecado: usa el stack XLibre/dinit, que ya no aplica.

Estado verificado el 2026-11-02 en la laptop (Mint 22.2).

## Común a las dos máquinas

| Qué | Para qué | Mint (apt) | Arch |
|---|---|---|---|
| zsh | shell | `zsh` | `zsh` |
| Zap | plugins de zsh | instalador: `zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1` | `zap-git` (AUR) |
| oh-my-posh | prompt | binario en `~/.local/bin` (`curl -s https://ohmyposh.dev/install.sh \| bash -s`) | `oh-my-posh-bin` (AUR) |
| eza | aliases `ls`/`l`/`ll`/`lt` | `eza` | `eza` |
| neovim | `alias vim=nvim` | `neovim` | `neovim` |
| fastfetch | al abrir la shell | `fastfetch` | `fastfetch` |
| tree | `alias tree` | `tree` | `tree` |
| kitty | terminal (dwm, sxhkd, scratchpads) | `kitty` | `kitty` |
| btop | scratchpad `spbtop` | `btop` | `btop` |
| flameshot | capturas (`Super+Shift+s`) | `flameshot` | `flameshot` |
| nemo | archivos (`Super+e` en sxhkd) | `nemo` | `nemo` |
| Zed | editor | binario en `~/.local/bin/zed` (`curl -f https://zed.dev/install.sh \| sh`) | `zed` |
| stow | deploy de los dotfiles | `stow` | `stow` |
| GoMono Nerd Font | dwm, slstatus, Zed | a mano en `~/.local/share/fonts` | `ttf-go-nerd` |

## Laptop — X11 / dwm (Mint)

### Compilar suckless (`suckless/`)

`build-essential git libx11-dev libxft-dev libxinerama-dev libfreetype-dev libfontconfig-dev`

### Sesión (`dwm/.dwm/autostart.sh`, `monitor-setup.sh`)

| Paquete apt | Uso |
|---|---|
| `x11-xserver-utils` | `xrandr` (monitores) |
| `feh` | wallpaper (`~/Pictures/background`) |
| `sxhkd` | keybindings de apps |
| `picom` | compositor |
| `xautolock` + `cinnamon-screensaver` | bloqueo a los 15 min, suspensión a los 30 |
| `policykit-1-gnome` | agente polkit |

### dwm (`config.h`)

| Paquete | Uso |
|---|---|
| `suckless-tools` | `dmenu_run` en `Super+p`. **No está instalado.** |
| `wireplumber` | `wpctl` para volumen y micrófono |
| `brightnessctl` | brillo, vía `/usr/local/bin/brightness-control` (wrapper no versionado que llama a `brightnessctl "$@"`, con una regla en `/etc/sudoers.d/brightness`) |
| mise → `lazydocker` | scratchpad `spdocker` (usa la ruta del shim de mise) |

### sxhkd (`sxhkdrc`)

`rofi` (`Super+r`), `brave-browser` (repo de Brave), `icaclient` (Citrix Workspace, `.deb` de Citrix).

### slstatus (`slstatus-src/config.h`)

`wireless-tools` (`iwgetid`, para la banda wifi), `wireplumber` (`wpctl`), `gawk`/`mawk` (`awk`).

### Clipboard (`clipboard/`)

`python3` y `xclip`, más las librerías `libX11` y `libXfixes` que carga `ctypes` (ya vienen con cualquier sesión X). El servicio de usuario `clip-normalize` lo arranca `autostart.sh`.

### Apps que usan las reglas de dwm

Slack (`slack-desktop`, `.deb`), Telegram, GIMP.

### Entorno de desarrollo (paquetes `mise/` + `zsh/.config/zsh/conf.d/dev.zsh`)

`mise` (`curl https://mise.run | sh`) y después `mise install`, que instala todo lo que está en `mise/.config/mise/config.toml`: terraform, terragrunt, tflint, terraform-docs, trivy, pre-commit, actionlint, tf-summarize, tftui, aws-cli, granted, e1s, k9s, kubectl, python 3.12, uv, ruff, node 22, aws-cdk, lazygit, lazydocker, gh, fzf, yq, bat, delta, fd, zoxide, glow, syft.

Opcionales (se activan solo si existen): `~/.dotnet/tools` (ilspycmd), `~/.opencode/bin` (opencode), `~/.npm-global/bin`.

## Desktop — Wayland / Hyprland (CachyOS)

Sale de los configs, sin verificar en la máquina (pacman; las de AUR están marcadas).

| Paquetes | Lo usa |
|---|---|
| `hyprland hypridle hyprlock hyprpaper hyprsunset` | `hypr/` (lua, idle, lock, wallpaper, `hyprsunset.sh`) |
| `xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt5-wayland qt6-wayland` | integración de apps con Wayland |
| `polkit-gnome` | agente polkit (exec en `hyprland.lua`) |
| `waybar` | barra (`waybar/`) |
| `wofi` | lanzador (`wofi/`, Waybar) |
| `wlogout` | menú de apagado (Waybar) |
| `pavucontrol` | click en el módulo de audio de Waybar |
| `pipewire pipewire-pulse wireplumber` | audio |
| `brightnessctl` | brillo (bindings) |
| `cava` | `hypr/Scripts/cava.sh`, módulo de Waybar |
| `playerctl` | control multimedia |
| `libnotify` | `notify-send` (gaming mode, hyprsunset) |
| `flameshot grim slurp wl-clipboard` | capturas y clipboard |
| `dunst` | notificaciones |
| `kitty` | terminal |
| `ttf-jetbrains-mono-nerd ttf-jetbrains-mono ttf-go-nerd noto-fonts noto-fonts-emoji` | Waybar, ghostty, Zed |
| `paru` (AUR helper) | `in` y los aliases `up/un/pl/pa/pc/po` del `.zshrc` |

## Pendientes detectados

- **dmenu no está instalado en la laptop:** `Super+p` (dmenu_run) no hace nada. Las opciones son `sudo apt install suckless-tools` o pasar el bind a rofi.
- **tree no está instalado en la laptop:** existe el alias `tree`, pero falta el binario (`sudo apt install tree`).
- **ghostty:** hay config en `ghostty/`, pero no está instalado en la laptop.
- **Scripts de instalación del Desktop:** `artix-base-install.sh` y `artix-post-install.sh` están deprecados. Hay que rearmarlos sobre CachyOS, sin el stack XLibre/dinit.
- **brightness-control y su regla de sudoers** viven fuera del repo. En una reinstalación hay que recrearlos a mano.
- **Fuente de GoMono Nerd Font en Mint:** no hay paquete apt, se instala a mano.
