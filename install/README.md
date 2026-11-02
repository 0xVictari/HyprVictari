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

O módulo por módulo (`--core` primero): `--core`, `--cinnamon`, `--hyprland`, `--apps`, `--dotfiles`.

| Módulo | Qué hace |
|---|---|
| `--core` | paru (repos de CachyOS o AUR), pipewire, polkit-gnome, gnome-keyring y ly (`ly@tty2`, animación matrix). Deshabilita SDDM o cualquier otro DM. |
| `--cinnamon` | Cinnamon sobre Xorg, Nemo y Xapps (xed, xreader, xviewer), como sesión de respaldo. |
| `--hyprland` | Todo lo que usan `hypr/`, `waybar/` y `wofi/`, incluidos cava, playerctl y libnotify. |
| `--apps` | Apps de usuario, theming, zsh, oh-my-posh y Zap. |
| `--dotfiles` | Clona o actualiza el repo y respalda lo que choque en `~/.dotfiles-backup-<fecha>/`. Después hace stow de `zsh ohmyposh hyprland waybar wofi kitty ghostty zed fastfetch` y pone zsh como shell. |

Las listas de paquetes están al principio del script; `PACKAGES.md` las documenta.

## Después

- Reiniciar. En ly se elige entre Hyprland y Cinnamon.
- Servicios opcionales: ufw, power-profiles-daemon y syncthing (el script imprime los comandos).
- Llave SSH para pushear: el clon es por HTTPS, pero el push ya apunta a `git@github.com`.
- **No** stowear `mise` en el Desktop: el entorno de desarrollo es solo de la laptop.

## A verificar en la primera instalación

- Que la ISO ofrezca "No Desktop".
- Que paru venga en los repos de CachyOS (si no, el script lo compila desde el AUR).
- Que ly arranque limpio después de Plymouth. En Artix hacía falta un reset de TTY en `/etc/ly/startup.sh`; con systemd no debería hacer falta.
- Que `zap-git` y `oh-my-posh-bin` sigan existiendo en el AUR con esos nombres.
