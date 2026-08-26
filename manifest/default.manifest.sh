#!/usr/bin/env bash

DOTBOOTSTRAP_NAME="japonamat-dotfiles"
DOTBOOTSTRAP_VERSION="1"

DOTBOOTSTRAP_COMPONENTS=(
  "local-bin|bin|.local/bin|required|Portable helper scripts"
  "alacritty|alacritty|.config/alacritty|required|Alacritty config"
  "btop|btop|.config/btop|optional|btop config"
  "fish|fish|.config/fish|optional|Fish shell config"
  "gtk3|gtk-3.0|.config/gtk-3.0|optional|GTK3 settings"
  "gtk4|gtk-4.0|.config/gtk-4.0|optional|GTK4 settings"
  "hypr|hypr|.config/hypr|optional|Hyprland config"
  "mako|mako|.config/mako|optional|Mako notifications"
  "micro|micro|.config/micro|optional|Micro editor config"
  "niri|niri|.config/niri|optional|Niri compositor config"
  "nvim|nvim|.config/nvim|optional|Neovim config"
  "qt5ct|qt5ct|.config/qt5ct|optional|Qt5 theme config"
  "qt6ct|qt6ct|.config/qt6ct|optional|Qt6 theme config"
  "ranger|ranger|.config/ranger|optional|Ranger config"
  "rofi|rofi|.config/rofi|optional|Rofi config"
  "swayidle|swayidle|.config/swayidle|optional|swayidle config"
  "swaylock|swaylock|.config/swaylock|optional|swaylock config"
  "wlogout|wlogout|.config/wlogout|optional|wlogout config"
  "zathura|zathura|.config/zathura|optional|Zathura config"
  "mimeapps|mimeapps.list|.config/mimeapps.list|optional|MIME associations"
  "user-dirs|user-dirs.dirs|.config/user-dirs.dirs|optional|XDG user dirs"
  "xdg-terminals|xdg-terminals.list|.config/xdg-terminals.list|optional|XDG terminal mapping"
)

DOTBOOTSTRAP_DEFAULT_COMPONENTS=(
  "local-bin"
  "alacritty"
  "fish"
  "gtk3"
  "gtk4"
  "mako"
  "niri"
  "nvim"
  "qt5ct"
  "qt6ct"
  "ranger"
  "rofi"
  "swayidle"
  "swaylock"
  "wlogout"
  "zathura"
  "mimeapps"
  "user-dirs"
  "xdg-terminals"
)

DOTBOOTSTRAP_PACKAGE_GROUPS=(
  "base|always|git curl unzip|Base bootstrap tools"
  "wayland-core|always|foot alacritty wl-clipboard xdg-desktop-portal-gtk xdg-desktop-portal-gnome|Wayland userland basics"
  "niri-desktop|always|niri waybar mako rofi swayidle swaylock wlogout playerctl|Niri desktop stack"
  "shell|always|fish btop|Shell and terminal helpers"
  "editors|always|neovim micro|Editors"
  "file-tools|always|ranger zathura zathura-pdf-mupdf|File manager and PDF viewer"
  "theme|always|qt5ct qt6ct nwg-look|Theme helpers"
  "laptop-backlight|backlight|brightnessctl light|Brightness control tools for laptops"
  "wireless|wifi bluetooth|networkmanager bluez bluez-utils|Wireless stack for laptops"
  "laptop-ux|laptop battery|tlp|Laptop power management"
  "intel-gpu-tools|intel_gpu|intel-media-driver vulkan-intel|Intel graphics userland"
  "amd-gpu-tools|amd_gpu|mesa vulkan-radeon|AMD graphics userland"
  "optional-gui|always|nemo imv telegram-desktop hyprpicker wl-color-picker|Optional GUI apps referenced by config"
)

DOTBOOTSTRAP_DEFAULT_PACKAGE_GROUPS=(
  "base"
  "wayland-core"
  "niri-desktop"
  "shell"
  "editors"
  "file-tools"
  "theme"
  "laptop-backlight"
  "wireless"
  "laptop-ux"
  "intel-gpu-tools"
  "amd-gpu-tools"
)

DOTBOOTSTRAP_OPTIONAL_PACKAGE_GROUPS=(
  "optional-gui"
)

DOTBOOTSTRAP_RELEVANCE_WARN_PATTERNS=(
  '/home/'
  'userapp-'
)
