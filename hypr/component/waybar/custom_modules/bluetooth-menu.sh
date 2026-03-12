#!/usr/bin/env bash

set -euo pipefail

ROFI_THEME="$HOME/.config/rofi/launchers/type-2/style-10.rasi"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Bluetooth" "$1"
    fi
}

rofi_cmd() {
    if [[ -f "$ROFI_THEME" ]]; then
        rofi -dmenu -i -p "$1" -theme "$ROFI_THEME"
    else
        rofi -dmenu -i -p "$1"
    fi
}

adapter_powered() {
    bluetoothctl show | awk -F': ' '/Powered:/ {print $2; exit}'
}

device_line() {
    local mac="$1"
    local name="$2"
    local info connected paired trusted icon

    info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
    connected="$(printf '%s\n' "$info" | awk -F': ' '/Connected:/ {print $2; exit}')"
    paired="$(printf '%s\n' "$info" | awk -F': ' '/Paired:/ {print $2; exit}')"
    trusted="$(printf '%s\n' "$info" | awk -F': ' '/Trusted:/ {print $2; exit}')"

    if [[ "$connected" == "yes" ]]; then
        icon="󰂱"
    elif [[ "$paired" == "yes" ]]; then
        icon="󰂯"
    else
        icon="󰂰"
    fi

    printf '%s  %s  [%s]%s%s\n' \
        "$icon" \
        "$name" \
        "$mac" \
        "${paired:+ paired=$paired}" \
        "${trusted:+ trusted=$trusted}"
}

device_menu() {
    local mac="$1"
    local name="$2"
    local info connected paired trusted action

    info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
    connected="$(printf '%s\n' "$info" | awk -F': ' '/Connected:/ {print $2; exit}')"
    paired="$(printf '%s\n' "$info" | awk -F': ' '/Paired:/ {print $2; exit}')"
    trusted="$(printf '%s\n' "$info" | awk -F': ' '/Trusted:/ {print $2; exit}')"

    action="$(
        {
            if [[ "$connected" == "yes" ]]; then
                printf 'Disconnect\n'
            else
                printf 'Connect\n'
            fi
            if [[ "$paired" != "yes" ]]; then
                printf 'Pair\n'
            fi
            if [[ "$trusted" == "yes" ]]; then
                printf 'Untrust\n'
            else
                printf 'Trust\n'
            fi
            printf 'Remove\n'
        } | rofi_cmd "$name"
    )"

    [[ -n "${action:-}" ]] || exit 0

    case "$action" in
        Connect)
            bluetoothctl connect "$mac" >/dev/null && notify "Connected: $name"
            ;;
        Disconnect)
            bluetoothctl disconnect "$mac" >/dev/null && notify "Disconnected: $name"
            ;;
        Pair)
            bluetoothctl pair "$mac" >/dev/null && notify "Paired: $name"
            ;;
        Trust)
            bluetoothctl trust "$mac" >/dev/null && notify "Trusted: $name"
            ;;
        Untrust)
            bluetoothctl untrust "$mac" >/dev/null && notify "Untrusted: $name"
            ;;
        Remove)
            bluetoothctl remove "$mac" >/dev/null && notify "Removed: $name"
            ;;
    esac
}

main_menu() {
    local powered selection mac name

    powered="$(adapter_powered || true)"

    selection="$(
        {
            if [[ "$powered" == "yes" ]]; then
                printf 'Power off Bluetooth\n'
            else
                printf 'Power on Bluetooth\n'
            fi
            printf 'Scan for devices\n'
            bluetoothctl devices | while read -r _ mac name; do
                [[ -n "${mac:-}" && -n "${name:-}" ]] || continue
                device_line "$mac" "$name"
            done
        } | rofi_cmd "Bluetooth"
    )"

    [[ -n "${selection:-}" ]] || exit 0

    case "$selection" in
        "Power on Bluetooth")
            bluetoothctl power on >/dev/null && notify "Bluetooth powered on"
            exit 0
            ;;
        "Power off Bluetooth")
            bluetoothctl power off >/dev/null && notify "Bluetooth powered off"
            exit 0
            ;;
        "Scan for devices")
            alacritty -e bash -lc 'bluetoothctl --timeout 15 scan on; printf "\nPress Enter to close..."; read -r _'
            exit 0
            ;;
    esac

    mac="$(printf '%s\n' "$selection" | grep -oE '\[[^]]+\]' | tr -d '[]' || true)"
    [[ -n "$mac" ]] || exit 0

    name="$(printf '%s\n' "$selection" | sed -E 's/^.\s\s(.*?)\s\s\[[^]]+\].*$/\1/')"
    device_menu "$mac" "$name"
}

main_menu
