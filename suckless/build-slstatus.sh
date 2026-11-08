#!/usr/bin/env bash
# Compila slstatus (submódulo upstream) con slstatus-src/config.h.
#
#   ./build-slstatus.sh            compila y deja el binario en slstatus/ para probar
#   ./build-slstatus.sh --install  compila, instala con sudo y reinicia slstatus
#                                  (solo si ya estaba corriendo, o sea en dwm)
#
# Probar sin tocar la barra: ./slstatus/slstatus -s -1
# Los bloques wifi y temperatura llaman a ~/.dwm/slstatus-{wifi,temp}.sh
# (paquete stow dwm); sin ellos muestran n/a.
set -euo pipefail
cd "$(dirname "$0")"

cp slstatus-src/config.h slstatus/config.h
make -C slstatus

if [[ ${1:-} == --install ]]; then
  sudo make -C slstatus install
  make -C slstatus clean
  rm -f slstatus/config.h
  # Arrancarlo desde otra sesión (Hyprland con XWayland, Cinnamon) lo dejaría
  # corriendo suelto; en dwm lo arranca ~/.dwm/autostart.sh.
  if pkill -x slstatus; then
    setsid slstatus >/dev/null 2>&1 &
    echo "slstatus instalado y reiniciado."
  else
    echo "slstatus instalado (no estaba corriendo; lo arranca la sesión dwm)."
  fi
fi
