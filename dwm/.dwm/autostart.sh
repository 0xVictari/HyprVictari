#!/bin/bash
# Arranque de la sesión dwm (patch autostart). Tiene que andar en Debian/Mint y
# en Arch, en cualquier máquina: nada de nombres de hardware fijos acá.

# Monitores + wallpaper (el mismo script que Super+Shift+m)
~/.dwm/monitor-setup.sh

sxhkd &
slstatus &
# Agente polkit: la ruta cambia entre Debian/Mint y Arch
for agent in /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
             /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1; do
    [ -x "$agent" ] && { "$agent" & break; }
done
xautolock -time 15 -locker "cinnamon-screensaver-command -l" \
 -killtime 30 -killer "systemctl suspend" &
picom -b &

# Clipboard Zed -> Citrix (paquete stow clipboard/). dwm no activa graphical-session.target
systemctl --user start clip-normalize
