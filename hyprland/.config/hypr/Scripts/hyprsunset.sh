#!/bin/bash

current_hour=$(date +%H)

if [ $current_hour -ge 20 ] || [ $current_hour -lt 7 ]; then
    # Evening/night: warm (4000K)
    hyprsunset -t 4000
else
    # Daytime: normal
    hyprsunset
fi
