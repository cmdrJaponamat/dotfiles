#!/usr/bin/env bash

set -eu

touchscreen_script="$HOME/.config/niri/waybar/custom_modules/touchscreen-toggle.sh"

update_count() {
    if command -v checkupdates >/dev/null 2>&1; then
        checkupdates 2>/dev/null | wc -l
    else
        printf '0\n'
    fi
}

touchscreen_state() {
    if "$touchscreen_script" is-enabled >/dev/null 2>&1; then
        printf 'on\n'
    else
        printf 'off\n'
    fi
}

print_status() {
    updates="$(update_count)"
    touch="$(touchscreen_state)"
    class="off"
    if [ "$updates" -gt 0 ] || [ "$touch" = "off" ]; then
        class="attention"
    fi

    tooltip="Utilities\nUpdates: ${updates}\nTouchscreen: ${touch}"
    printf '{"text":"󱂬","class":"%s","tooltip":"%s"}\n' "$class" "$tooltip"
}

show_menu() {
    updates="$(update_count)"
    touch="$(touchscreen_state)"

    choice="$(printf 'System update (%s)\nTouchscreen: %s\n' "$updates" "$touch" | rofi -dmenu -i -p 'Utilities')"

    case "$choice" in
        "System update ("*)
            alacritty -e bash -lc 'paru'
            ;;
        "Touchscreen: on")
            alacritty -e bash -lc '$HOME/.config/niri/waybar/custom_modules/touchscreen-toggle.sh toggle'
            ;;
        "Touchscreen: off")
            alacritty -e bash -lc '$HOME/.config/niri/waybar/custom_modules/touchscreen-toggle.sh toggle'
            ;;
        *)
            ;;
    esac
}

case "${1:-status}" in
    status)
        print_status
        ;;
    menu)
        show_menu
        ;;
    *)
        printf 'Usage: %s [status|menu]\n' "$0" >&2
        exit 1
        ;;
esac
