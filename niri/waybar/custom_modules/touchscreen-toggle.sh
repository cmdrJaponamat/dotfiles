#!/usr/bin/env bash

set -eu

driver_dir="/sys/bus/hid/drivers/hid-multitouch"
signal="9"

resolve_device_id() {
    local preferred=""
    local candidate=""

    for candidate in \
        "$driver_dir"/0018:27C6:0114.* \
        /sys/bus/hid/devices/0018:27C6:0114.* \
        "$driver_dir"/0018:27C6:01E0.* \
        /sys/bus/hid/devices/0018:27C6:01E0.*
    do
        [ -e "$candidate" ] || continue
        preferred="$(basename "$candidate")"
        printf '%s\n' "$preferred"
        return 0
    done

    return 1
}

is_enabled() {
    local device_id
    device_id="$(resolve_device_id)" || return 1
    [ -L "$driver_dir/$device_id" ]
}

print_status() {
    if is_enabled; then
        printf '{"text":"TS","class":"on","tooltip":"Touchscreen: on\\nLeft click: toggle"}\n'
    else
        printf '{"text":"TS","class":"off","tooltip":"Touchscreen: off\\nLeft click: toggle"}\n'
    fi
}

toggle_touchscreen() {
    local device_id
    device_id="$(resolve_device_id)" || {
        printf 'Touchscreen device not found.\n' >&2
        exit 1
    }

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
