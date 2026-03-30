#!/usr/bin/env bash

set -eu

device_id="0018:27C6:0114.0003"
driver_dir="/sys/bus/hid/drivers/hid-multitouch"
signal="9"

is_enabled() {
    [ -L "$driver_dir/$device_id" ]
}

print_status() {
    if is_enabled; then
        printf '{"text":"󰍹","tooltip":"Touchscreen: on\\nLeft click: toggle"}\n'
    else
        printf '{"text":"󰍺","tooltip":"Touchscreen: off\\nLeft click: toggle"}\n'
    fi
}

toggle_touchscreen() {
    if is_enabled; then
        printf '%s' "$device_id" | sudo tee "$driver_dir/unbind" >/dev/null
        printf 'Touchscreen disabled: %s\n' "$device_id"
    else
        printf '%s' "$device_id" | sudo tee "$driver_dir/bind" >/dev/null
        printf 'Touchscreen enabled: %s\n' "$device_id"
    fi

    pkill -RTMIN+"$signal" waybar 2>/dev/null || true
}

case "${1:-status}" in
    status)
        print_status
        ;;
    is-enabled)
        is_enabled
        ;;
    toggle)
        toggle_touchscreen
        ;;
    *)
        printf 'Usage: %s [status|toggle]\n' "$0" >&2
        exit 1
        ;;
esac
