#!/usr/bin/env bash

DOTBOOTSTRAP_NAME="japonamat-dotfiles"
DOTBOOTSTRAP_VERSION="1"

DOTBOOTSTRAP_COMPONENTS=(
  "local-bin|bin|.local/bin|required|Portable helper scripts"
  "alacritty|alacritty|.config/alacritty|required|Alacritty config"
  "autostart|autostart|.config/autostart|optional|XDG autostart overrides"
  "btop|btop|.config/btop|optional|btop config"
  "fish|fish|.config/fish|optional|Fish shell config"
  "gtk3|gtk-3.0|.config/gtk-3.0|optional|GTK3 settings"
  "gtk4|gtk-4.0|.config/gtk-4.0|optional|GTK4 settings"
  "kvantum|Kvantum|.config/Kvantum|optional|Kvantum Qt theme"
  "hypr|hypr|.config/hypr|optional|Hyprland config"
  "mako|mako|.config/mako|optional|Mako notifications"
  "micro|micro|.config/micro|optional|Micro editor config"
  "niri|niri|.config/niri|optional|Niri compositor config"
  "nvim|nvim|.config/nvim|optional|Neovim config"
  "qt5ct|qt5ct|.config/qt5ct|optional|Qt5 theme config"
  "qt6ct|qt6ct|.config/qt6ct|optional|Qt6 theme config"
  "ranger|ranger|.config/ranger|optional|Ranger config"
  "rofi|rofi|.config/rofi|optional|Rofi config"
  "sddm-theme|sddm/silent|/usr/share/sddm/themes/silent|optional|SilentSDDM theme"
  "sddm-config|sddm/10-theme.conf|/etc/sddm.conf.d/10-theme.conf|optional|SDDM theme selection"
  "sddm-greeter|sddm/20-silent-general.conf|/etc/sddm.conf.d/20-silent-general.conf|optional|SilentSDDM greeter environment"
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
  "autostart"
  "fish"
  "gtk3"
  "gtk4"
  "kvantum"
  "mako"
  "niri"
  "nvim"
  "qt5ct"
  "qt6ct"
  "ranger"
  "rofi"
  "sddm-theme"
  "sddm-config"
  "sddm-greeter"
  "swayidle"
  "swaylock"
  "wlogout"
  "zathura"
  "mimeapps"
  "user-dirs"
  "xdg-terminals"
)

DOTBOOTSTRAP_PACKAGE_GROUPS=(
  "bootstrap-tools|minimal|always|git curl unzip|Base bootstrap tools"
  "session-base|minimal|always|foot alacritty wl-clipboard xdg-desktop-portal-gtk xdg-desktop-portal-gnome|Minimal Wayland session base"
  "niri-session|core|always|niri waybar mako rofi playerctl|Core Niri desktop session"
  "lockscreen|core|always|swayidle swaylock|Session lock tools"
  "display-manager|core|always|sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6-imageformats|Display manager and SilentSDDM runtime"
  "shell-tools|core|always|fish btop|Shell and terminal helpers"
  "editor-base|core|always|neovim|Primary editor"
  "extra-editors|full|always|micro|Secondary editor"
  "file-tools|core|always|ranger zathura zathura-pdf-mupdf|File manager and PDF viewer"
  "theme-tools|full|always|qt5ct qt6ct nwg-look|Theme helpers"
  "laptop-backlight|minimal|backlight|brightnessctl light|Brightness control tools for laptops"
  "wireless|minimal|wifi bluetooth|networkmanager bluez bluez-utils|Wireless stack for laptops"
  "laptop-power|core|laptop battery|tlp|Laptop power management"
  "intel-gpu-tools|minimal|intel_gpu|intel-media-driver vulkan-intel|Intel graphics userland"
  "amd-gpu-tools|minimal|amd_gpu|mesa vulkan-radeon|AMD graphics userland"
  "optional-gui|full|always|nemo imv telegram-desktop hyprpicker wl-color-picker|Optional GUI apps referenced by config"
)

DOTBOOTSTRAP_PACKAGE_PRESETS=(
  "minimal|bootstrap-tools session-base laptop-backlight wireless intel-gpu-tools amd-gpu-tools|Minimal bootable user environment"
  "core|minimal niri-session lockscreen shell-tools editor-base file-tools laptop-power|Daily-driver desktop setup"
  "full|core extra-editors theme-tools optional-gui|Full featured setup with optional apps"
)

DOTBOOTSTRAP_DEFAULT_PACKAGE_PRESET="core"

DOTBOOTSTRAP_OPTIONAL_FLOWS=(
  "aur-helper|always|Install an AUR helper manually if you want AUR-backed extras later|Example: yay or paru"
  "wlogout-aur|always|Install wlogout manually from AUR or another trusted source before treating the power menu as complete|The copied config is ready in ~/.config/wlogout"
  "slimbookbattery|laptop battery|Optional tray frontend for TLP profiles; keep disabled by default unless you want live profile switching|AUR/manual install only"
  "nvidia-proprietary|nvidia_gpu|Review proprietary NVIDIA driver flow manually before treating install as complete|Packages depend on GPU generation and kernel choice"
  "display-manager-enable|always|If SDDM was installed, enable its system service before reboot|sudo systemctl enable sddm.service"
  "wireless-services|wifi bluetooth|Enable runtime services for wireless hardware if the machine needs them|sudo systemctl enable --now NetworkManager bluetooth"
  "tlp-enable|laptop battery|Enable TLP after package install on laptops|sudo systemctl enable --now tlp.service"
)

DOTBOOTSTRAP_RELEVANCE_WARN_PATTERNS=(
  '/home/'
  'userapp-'
)
