# Instalación

- **Desktop (CachyOS + Hyprland):** secciones 1 y 2.
- **Sesión suckless (dwm + slstatus + sxhkd)** en Mint/Debian/Ubuntu o Arch/CachyOS: `./install/suckless-setup.sh --all`, corrido como usuario (no root). Ver `--help`.

# Desktop (CachyOS)

Dos pasos: el instalador oficial hace la base y `cachyos-post-install.sh`
instala el resto y despliega los dotfiles.

## 1. Instalador de CachyOS (Calamares)

Opciones a elegir:

| Paso | Elección | Por qué |
|---|---|---|
| Bootloader | Limine (default) | Con btrfs, muestra los snapshots en el menú de arranque (limine-snapper-sync). Con ext4 funciona igual, sin esa parte. |
| Particionado | Borrar disco, **Encrypt system** (LUKS2); sistema de archivos **btrfs** o **ext4** | Una sola passphrase al bootear. btrfs es el default y da snapshots: si un update rompe algo, se vuelve atrás desde el menú de Limine. ext4 también es una opción válida (igual que xfs, f2fs o zfs): es más simple, pero no tiene snapshots y el rescate es por TTY o desde un live USB. El post-install no depende de cuál elijas. |
| Swap | Con hibernación (swap ≥ RAM) | Con systemd en el initramfs, la misma passphrase abre root y swap. Ya no hace falta el truco de `openswap` de Artix. |
| Escritorio | **Ninguno / No Desktop** si existe la opción (a verificar en la ISO) | El post-install instala Hyprland y Cinnamon con nuestra config. Si hay que elegir uno, Cinnamon. **No** elegir la edición Hyprland de CachyOS: trae `cachyos-hyprland-settings`, que choca con los dotfiles (el script ofrece desinstalarlo). |
| Teclado | Español (Latinoamérica) | |
| Zona horaria / locale | America/Argentina/Cordoba; idioma en_US.UTF-8, formatos es_AR | Igual que antes. |
| Usuario | El de siempre | |

Plymouth viene configurado de fábrica, así que el prompt de LUKS ya es gráfico.

## 2. Post-install

Desde una TTY o terminal, ya con red:

```bash
git clone https://github.com/0xVictari/HyprVictari.git ~/HyprVictari
cd ~/HyprVictari/install
sudo ./cachyos-post-install.sh --all
```

O módulo por módulo (`--core` primero): `--core`, `--cinnamon`, `--hyprland`, `--apps`, `--dotfiles`. `--gaming` va aparte: `--all` no lo incluye.

| Módulo | Qué hace |
|---|---|
| `--core` | paru (repos de CachyOS o AUR), pipewire, polkit-gnome, gnome-keyring, bluetooth (bluez + blueman, servicio habilitado) y ly (`ly@tty2`, animación matrix). Deshabilita SDDM o cualquier otro DM. |
| `--cinnamon` | Cinnamon sobre Xorg, Nemo y Xapps (xed, xreader, xviewer), como sesión de respaldo. Instala ghostty y lo deja como terminal por defecto de Cinnamon (override de gschema: Ctrl+Alt+T y "Abrir en terminal" de Nemo, también desde Hyprland). |
| `--hyprland` | Todo lo que usan `hypr/`, `waybar/` y `wofi/`, incluidos cava, playerctl y libnotify. Waybar es `waybar-git` (AUR): si está el `waybar` de los repos, lo saca antes. |
| `--apps` | Apps de usuario (incluidas discord, element, obsidian y qbittorrent), theming, zsh y oh-my-posh. |
| `--dotfiles` | Clona o actualiza el repo y respalda lo que choque en `~/.dotfiles-backup-<fecha>/`. Crea `~/.config/zsh` y `~/.config/kitty` como carpetas reales, hace stow de `zsh ohmyposh hyprland waybar wofi dunst kitty ghostty zed fastfetch`, clona Zap en `~/.local/share/zap` y pone zsh como shell. |
| `--gaming` | `cachyos-gaming-meta` (wine, proton, umu, libs de 32 bits; sin Steam), openmw, melonDS (`melonds-bin`), Nugget Doom y el GZDoom 4.10.0 portable para doom-infinite (ver abajo). |

Zap **no** es el paquete `zap-git` del AUR: ese es issmirnov/zap, un programa de atajos web. El Zap de zsh se clona de `github.com/zap-zsh/zap` (rama `release-v1`); el `install.zsh` oficial no se usa porque reescribe `~/.zshrc`. `./check.sh` verifica que zsh cargue Zap, los plugins y oh-my-posh.

Las listas de paquetes están al principio del script; `PACKAGES.md` las documenta.

## Después

- Reiniciar. En ly se elige entre Hyprland y Cinnamon.
- Servicios opcionales: ufw, power-profiles-daemon y syncthing (el script imprime los comandos).
- Llave SSH para pushear: el clon es por HTTPS, pero el push ya apunta a `git@github.com`.
- **No** stowear `mise` en el Desktop: el entorno de desarrollo es solo de la laptop.
- Si en dconf ya había otra terminal elegida para Cinnamon, manda sobre el default del script: `gsettings set org.cinnamon.desktop.default-applications.terminal exec ghostty` y `... exec-arg -e`.

### doom-infinite

doom-infinite (0.98 PP2) solo anda con **GZDoom 4.10.0**: su README pide "4.8.2 o mayor", pero con versiones nuevas falla. No hay GZDoom ni UZDoom del sistema (no se usan para otra cosa). `--gaming` baja el portable oficial (`GZDoom.v4.10.0.LinuxPortable.tar.xz` de la versión `g4.10.0` en GitHub, con checksum fijo) a `~/doomwads/GZDoom.v4.10.0.LinuxPortable/`. A mano van `DOOM2.WAD` y `DOOM_Infinite_098_PP2_H3.pk3` (en esa carpeta) y `~/doomwads/doom-infinite.sh`:

```bash
#!/bin/bash
cd ~/doomwads/GZDoom.v4.10.0.LinuxPortable/
./gzdoom -iwad ~/doomwads/DOOM2.WAD -file ~/doomwads/GZDoom.v4.10.0.LinuxPortable/DOOM_Infinite_098_PP2_H3.pk3
```

`.zshrc` crea el alias `doom-infinite` si ese script existe, y el modo gaming de Hyprland lo detecta (el proceso se llama `gzdoom`).

## A verificar en la primera instalación

- Que la ISO ofrezca "No Desktop".
- Que paru venga en los repos de CachyOS (si no, el script lo compila desde el AUR).
- Que ly arranque limpio después de Plymouth. En Artix hacía falta un reset de TTY en `/etc/ly/startup.sh`; con systemd no debería hacer falta.
- Que `oh-my-posh-bin`, `waybar-git`, `nugget-doom` y `melonds-bin` sigan existiendo en el AUR con esos nombres.
- Que `paru --noconfirm` no frene pidiendo revisar los PKGBUILD.
