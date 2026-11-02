#!/usr/bin/env bash
# Regenera victariwm/ desde dwm-flexipatch + victariwm-src/patches.h.
#
#   ./build-victariwm.sh            regenera victariwm/ (revisar con git diff)
#   ./build-victariwm.sh --install  regenera, compila como usuario e instala con sudo
#
# Fuentes de verdad:
#   victariwm-src/patches.h   qué patches están activos
#   victariwm/config.h        tu configuración (nunca se pisa)
#   victariwm-src/local/*.diff cambios propios al código, aplicados tras el finalizer
#   victariwm/config.def.h    config que genera el finalizer: si cambia tras activar
#                             un patch, pasar a mano las opciones nuevas a config.h
set -euo pipefail
cd "$(dirname "$0")"

FLEX=dwm-flexipatch
OUT=${OUT:-victariwm}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Árbol limpio de flexipatch en el commit fijado (no depende de su working tree)
mkdir "$tmp/src"
git -C "$FLEX" archive HEAD | tar -x -C "$tmp/src"
cp victariwm-src/patches.h "$tmp/src/patches.h"
cp "$tmp/src/config.def.h" "$tmp/src/config.h"

bash flexipatch-finalizer/flexipatch-finalizer.sh -r -d "$tmp/src" -o "$tmp/out" >"$tmp/finalizer.log" 2>&1 \
  || { cat "$tmp/finalizer.log"; exit 1; }

mv "$tmp/out/config.h" "$tmp/out/config.def.h"

# Cambios propios sobre el código finalizado (no existen como patch de flexipatch)
for d in victariwm-src/local/*.diff; do
  [[ -e $d ]] || continue
  patch -s -d "$tmp/out" -p1 < "$d" || { echo "No aplica: $d (regenerarlo sobre el código nuevo)"; exit 1; }
done
rsync -a --delete --exclude config.h "$tmp/out/" "$OUT/"

git -C "$OUT" status --short . || true

if [[ ${1:-} == --install ]]; then
  make -C "$OUT" clean all
  sudo make -C "$OUT" install
  make -C "$OUT" clean
  echo "Instalado. Reiniciar dwm para aplicar."
fi
