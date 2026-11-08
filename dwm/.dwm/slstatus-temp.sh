#!/bin/sh
# Temperatura del CPU en °C para slstatus (bloque CPU/temp).
# Busca el sensor en cada llamada: los números de thermal_zone y hwmon cambian
# entre boots y kernels, así que una ruta fija termina dando n/a.
#   1. thermal zone "x86_pkg_temp" (Intel, paquete)
#   2. hwmon coretemp / k10temp / zenpower, temp1 (Intel paquete, AMD Tctl)
# Solo builtins de sh: corre cada segundo.

for z in /sys/class/thermal/thermal_zone*; do
    [ -r "$z/type" ] || continue
    read -r t < "$z/type"
    if [ "$t" = x86_pkg_temp ] && read -r v < "$z/temp"; then
        echo $((v / 1000))
        exit 0
    fi
done

for h in /sys/class/hwmon/hwmon*; do
    [ -r "$h/name" ] || continue
    read -r n < "$h/name"
    case $n in
        coretemp|k10temp|zenpower)
            if read -r v < "$h/temp1_input"; then
                echo $((v / 1000))
                exit 0
            fi
            ;;
    esac
done

echo n/a
