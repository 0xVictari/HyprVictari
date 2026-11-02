#!/usr/bin/env bash
# Compila slstatus (submódulo upstream) con slstatus-src/config.h.
#
#   ./build-slstatus.sh            compila y deja el binario en slstatus/ para probar
#   ./build-slstatus.sh --install  compila, instala con sudo y reinicia slstatus
#
# Probar sin tocar la barra: ./slstatus/slstatus -s
set -euo pipefail
cd "$(dirname "$0")"

cp slstatus-src/config.h slstatus/config.h
make -C slstatus

if [[ ${1:-} == --install ]]; then
  sudo make -C slstatus install
  make -C slstatus clean
  rm -f slstatus/config.h
  pkill -x slstatus || true
  setsid slstatus >/dev/null 2>&1 &
  echo "slstatus instalado y reiniciado."
fi
