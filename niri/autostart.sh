#!/usr/bin/env bash

set -eu

niri_config="$HOME/.config/niri"
hypr_config="$HOME/.config/hypr"
waybar_dir="$niri_config/waybar"
wallpaper_dir="$hypr_config/wallpapers"
wallpaper_state="$HOME/.cache/niri/current_wallpaper"
waybar_log="$HOME/.cache/niri/waybar.log"
default_wallpaper="$wallpaper_dir/home-sweet-home.jpg"

if command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
    wallpaper_cmd="awww"
    wallpaper_daemon_cmd="awww-daemon"
elif command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
    wallpaper_cmd="swww"
    wallpaper_daemon_cmd="swww-daemon"
else
    wallpaper_cmd=""
    wallpaper_daemon_cmd=""
fi

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

if [ -n "$wallpaper_daemon_cmd" ]; then
    pgrep -x "$wallpaper_daemon_cmd" >/dev/null || "$wallpaper_daemon_cmd" >/dev/null 2>&1 &

    timeout=25
    while [ "$timeout" -gt 0 ]; do
        if "$wallpaper_cmd" query >/dev/null 2>&1; then
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

    if [ -f "$wallpaper" ] && "$wallpaper_cmd" query >/dev/null 2>&1; then
        "$wallpaper_cmd" img "$wallpaper" --transition-type center --transition-fps 60 --transition-step 20 &
    fi
fi

if [ -x "$hypr_config/scripts/rgb" ]; then
    "$hypr_config/scripts/rgb" &
fi
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
Telegram &
