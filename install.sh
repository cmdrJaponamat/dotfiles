#!/usr/bin/env bash
set -eu

REPO_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

cp -a "$REPO_DIR"/alacritty "$CONFIG_HOME"/
cp -a "$REPO_DIR"/btop "$CONFIG_HOME"/
cp -a "$REPO_DIR"/fish "$CONFIG_HOME"/
cp -a "$REPO_DIR"/gtk-3.0 "$CONFIG_HOME"/
cp -a "$REPO_DIR"/gtk-4.0 "$CONFIG_HOME"/
cp -a "$REPO_DIR"/hypr "$CONFIG_HOME"/
cp -a "$REPO_DIR"/mako "$CONFIG_HOME"/
cp -a "$REPO_DIR"/micro "$CONFIG_HOME"/
cp -a "$REPO_DIR"/niri "$CONFIG_HOME"/
cp -a "$REPO_DIR"/nvim "$CONFIG_HOME"/
cp -a "$REPO_DIR"/qt5ct "$CONFIG_HOME"/
cp -a "$REPO_DIR"/qt6ct "$CONFIG_HOME"/
cp -a "$REPO_DIR"/ranger "$CONFIG_HOME"/
cp -a "$REPO_DIR"/rofi "$CONFIG_HOME"/
cp -a "$REPO_DIR"/swayidle "$CONFIG_HOME"/
cp -a "$REPO_DIR"/swaylock "$CONFIG_HOME"/
cp -a "$REPO_DIR"/wlogout "$CONFIG_HOME"/
cp -a "$REPO_DIR"/zathura "$CONFIG_HOME"/
cp -a "$REPO_DIR"/mimeapps.list "$CONFIG_HOME"/
cp -a "$REPO_DIR"/user-dirs.dirs "$CONFIG_HOME"/
cp -a "$REPO_DIR"/xdg-terminals.list "$CONFIG_HOME"/
