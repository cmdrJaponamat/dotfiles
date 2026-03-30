#!/bin/bash

set -u

gpu_temp=""
for path in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
    if [ -r "$path" ]; then
        raw_temp=$(cat "$path")
        gpu_temp=$((raw_temp / 1000))
        break
    fi
done

if [ -z "$gpu_temp" ]; then
    text="󰢮 N/A"
else
    text="󰢮 ${gpu_temp}°C"
fi

deviceinfo=$(lspci | grep -Ei 'vga|3d|display' | head -n 1 | sed 's/^[^ ]* //' | sed 's/^VGA compatible controller: //')
if [ -z "$deviceinfo" ]; then
    deviceinfo="GPU"
fi

tooltip="$deviceinfo"
printf '{"text":"%s","class":"custom-gpu","tooltip":"%s"}\n' "$text" "$tooltip"
