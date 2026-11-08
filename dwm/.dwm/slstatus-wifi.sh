#!/bin/sh
# Wifi para slstatus: "SSID banda señal%", ej. "Casa_ 5G 80%".
# La interfaz es la primera de /proc/net/wireless (wlp1s0, wlan0... sin
# nombre fijo). SSID cortado a 5 caracteres; banda por la frecuencia que da
# iwgetid (Hz); señal = calidad del enlace / 70, como wifi_perc de slstatus.
# Sin wifi o sin conexión: n/a.

iface= q=
if [ -r /proc/net/wireless ]; then
    # Las dos primeras líneas son encabezado; los datos empiezan con "iface:"
    while read -r name _ quality _; do
        case $name in
            *:) iface=${name%:}; q=${quality%.}; break ;;
        esac
    done < /proc/net/wireless
fi
[ -n "$iface" ] || { echo n/a; exit 0; }

ssid=$(iwgetid "$iface" -r 2>/dev/null)
[ -n "$ssid" ] || { echo n/a; exit 0; }

band=$(iwgetid "$iface" -f -r 2>/dev/null |
    LC_ALL=C awk '{f = $1 / 1e9; print (f >= 5.9 ? "6G" : (f >= 4.9 ? "5G" : "2G"))}')

printf '%.5s %s %s%%\n' "$ssid" "$band" "$((${q:-0} * 100 / 70))"
