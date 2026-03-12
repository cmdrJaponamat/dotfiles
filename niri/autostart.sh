#!/usr/bin/env bash

set -eu

niri_config="$HOME/.config/niri"
hypr_config="$HOME/.config/hypr"
waybar_dir="$niri_config/waybar"
wallpaper_dir="$hypr_config/wallpapers"
wallpaper_state="$HOME/.cache/niri/current_wallpaper"
waybar_log="$HOME/.cache/niri/waybar.log"
default_wallpaper="$wallpaper_dir/home-sweet-home.jpg"

mkdir -p "$(dirname "$waybar_log")"

dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=niri NIRI_SOCKET

pkill waybar 2>/dev/null || true
(
    sleep 1
    pkill waybar 2>/dev/null || true
    exec waybar -l trace -c "$waybar_dir/config" -s "$waybar_dir/style.css" >"$waybar_log" 2>&1
) &

pkill mako 2>/dev/null || true
mako &

if command -v swww-daemon >/dev/null 2>&1; then
    pgrep -x swww-daemon >/dev/null || swww-daemon >/dev/null 2>&1 &

    timeout=25
    while [ "$timeout" -gt 0 ]; do
        if swww query >/dev/null 2>&1; then
            break
        fi
        sleep 0.2
        timeout=$((timeout - 1))
    done

    wallpaper="$default_wallpaper"
    if [ -f "$wallpaper_state" ]; then
        saved_wallpaper="$(cat "$wallpaper_state")"
        if [ -n "$saved_wallpaper" ] && [ -f "$saved_wallpaper" ]; then
            wallpaper="$saved_wallpaper"
        fi
    fi

    if [ -f "$wallpaper" ] && swww query >/dev/null 2>&1; then
        swww img "$wallpaper" --transition-type center --transition-fps 60 --transition-step 20 &
    fi
fi

if [ -x "$hypr_config/scripts/rgb" ]; then
    "$hypr_config/scripts/rgb" &
fi
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
Telegram &
slimbookbattery --minimize &
