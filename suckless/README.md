# Atajos — dwm (victariwm) + sxhkd

`Super` = tecla Windows · `Alt` = Mod1. Fuentes: `victariwm/config.h` y `../sxhkd/.config/sxhkd/sxhkdrc`.

## Apps (sxhkd)

| Atajo | Acción |
|---|---|
| `Super+q` | kitty |
| `Super+Shift+Enter` | kitty (dwm) |
| `Super+r` | rofi (lanzador) |
| `Super+p` | dmenu |
| `Super+e` | nemo |
| `Super+Shift+s` | captura de área (flameshot) |
| `Ctrl+Alt+l` | bloquear pantalla |
| `Super+Shift+b` | cerrar Brave (`killall brave`) |
| `Super+Shift+x` | cerrar Citrix (`killall wfica`) |
| `Super+Shift+m` | re-aplicar layout de monitores + wallpaper |

## Scratchpads (flotantes, misma tecla muestra/oculta)

| Atajo | Acción |
|---|---|
| `Super+s` | terminal |
| `Super+a` | btop |
| `Super+Shift+d` | lazydocker |

## Ventanas

| Atajo | Acción |
|---|---|
| `Super+j` / `Super+k` | foco siguiente / anterior |
| `Super+←↑→↓` | foco por dirección |
| `Super+Shift+j` / `Super+Shift+k` | mover ventana abajo / arriba en la pila |
| `Super+Enter` | pasar ventana a master |
| `Super+Shift+c` | cerrar ventana |
| `Super+Shift+Space` | alternar flotante |
| `Super+Shift+f` | fullscreen confinado a la ventana (fake fullscreen) |
| `Super+Shift+t` | sticky: visible en todos los tags |
| `Super+g` | centrar ventana flotante |

## Layout

| Atajo | Acción |
|---|---|
| `Super+t` / `Super+f` / `Super+m` | tile / flotante / monocle |
| `Super+Space` | alternar con el layout anterior |
| `Super+h` / `Super+l` | achicar / agrandar master |
| `Super+i` / `Super+d` | más / menos ventanas en master |
| `Super+b` | mostrar / ocultar barra |
| `Super+Alt+0` / `Super+Alt+Shift+0` | gaps on/off / gaps por defecto |
| `Super+Alt+u/i/o` (`+Shift` reduce) | gaps: todos / internos / externos |
| `Super+Alt+6/7/8/9` (`+Shift` reduce) | gaps: int. horiz. / int. vert. / ext. horiz. / ext. vert. |

## Tags

| Atajo | Acción |
|---|---|
| `Super+1..9` | ver tag |
| `Super+Shift+1..9` | mover ventana al tag |
| `Super+Ctrl+1..9` | sumar/quitar tag a la vista |
| `Super+Ctrl+Shift+1..9` | sumar/quitar tag a la ventana |
| `Super+0` / `Super+Shift+0` | ver todos / ventana en todos |
| `Super+Tab` | tag anterior |
| `Super+Ctrl+←` / `Super+Ctrl+→` | tag ocupado anterior / siguiente |
| `Super+n` | alternar nombres de tags (íconos / números) |

## Monitores

| Atajo | Acción |
|---|---|
| `Super+,` / `Super+.` | foco al monitor anterior / siguiente |
| `Super+Shift+,` / `Super+Shift+.` | mover ventana al otro monitor |
| `Super+Ctrl+Shift+,` / `Super+Ctrl+Shift+.` | mover **todas** las ventanas al otro monitor |

## Teclas multimedia

Volumen ±5 % y mute (`wpctl`), mute de micrófono, brillo ±5 %.

## Barra (clicks en el status)

| Bloque | Izq. | Der. | Rueda |
|---|---|---|---|
| Mic | mute/unmute | pavucontrol (entradas) | — |
| Volumen | mute | pavucontrol (salidas) | ±5 % (tope 100 %) |
| Reloj | notificación con la fecha | — | — |
| WiFi | `nmtui` en kitty | nm-connection-editor | — |
| CPU/temp, RAM | btop en kitty | — | — |
| Batería | notificación (estado, tiempo, consumo) | — | — |

Patch statuscmd: slstatus pone `\001`…`\006` antes de cada bloque (`slstatus-src/config.h`) y dwm corre `statuscmds[]` (`victariwm/config.h`) con el botón en `$BUTTON`.

## Sesión

| Atajo | Acción |
|---|---|
| `Super+Ctrl+Shift+q` | reiniciar dwm (mantiene ventanas) |
| `Super+Shift+q` | salir de dwm |

## Reglas automáticas

- Slack → tag 2 en la laptop (eDP-1) · Telegram → tag 3 · Gimp → tag 5
- Citrix → primer tag vacío del monitor externo (sin usar el 1); sin externo, primer tag vacío de la laptop

## Recompilar

```bash
./build-victariwm.sh --install          # dwm (patches en victariwm-src/patches.h)
./build-slstatus.sh --install          # slstatus (config en slstatus-src/config.h)
```
