#!/usr/bin/env bash

set -eu

niri_config="$HOME/.config/niri"
niri_wallpaper_dir="$niri_config/wallpapers"
legacy_wallpaper_dir="$HOME/.config/hypr/wallpapers"
wallpaper_state="$HOME/.cache/niri/current_wallpaper"
waybar_log="$HOME/.cache/niri/waybar.log"
rgb_candidate="$niri_config/scripts/rgb"
legacy_rgb_candidate="$HOME/.config/hypr/scripts/rgb"

has_wallpapers() {
    [ -d "$1" ] || return 1
    find "$1" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | grep -q .
}

if has_wallpapers "$niri_wallpaper_dir"; then
    wallpaper_dir="$niri_wallpaper_dir"
elif has_wallpapers "$legacy_wallpaper_dir"; then
    wallpaper_dir="$legacy_wallpaper_dir"
else
    wallpaper_dir="$niri_wallpaper_dir"
fi

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

export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=kvantum-dark

dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP=niri \
    NIRI_SOCKET \
    QT_QPA_PLATFORMTHEME \
    QT_STYLE_OVERRIDE

pkill waybar 2>/dev/null || true
(
    sleep 1
    pkill waybar 2>/dev/null || true
    exec "$HOME/.local/bin/relaunch-waybar"
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

if [ -x "$rgb_candidate" ]; then
    "$rgb_candidate" &
elif [ -x "$legacy_rgb_candidate" ]; then
    "$legacy_rgb_candidate" &
fi
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
