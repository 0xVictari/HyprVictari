#!/bin/bash
# Visualizador para el modulo custom/cava de Waybar.
# Un solo "cava | sed": si Waybar muere (killall waybar) sed y cava reciben SIGPIPE y
# terminan solos. Si cava sale al iniciar sesion (PipeWire todavia no esta),
# Waybar lo relanza por "restart-interval".

bars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
dict="s/;//g;"
for i in "${!bars[@]}"; do
    dict+="s/$i/${bars[i]}/g;"
done

config_file="${XDG_RUNTIME_DIR:-/tmp}/waybar-cava.conf"
cat > "$config_file" <<EOF
[general]
bars = 18

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

cava -p "$config_file" | sed -u "$dict"
