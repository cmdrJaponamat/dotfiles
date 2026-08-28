# dotfiles

Personal dotfiles for Arch Linux Wayland setup.

## Included
- alacritty
- btop
- autostart
- fish
- gtk-3.0
- gtk-4.0
- Kvantum
- hypr
- mako
- micro
- niri
- nvim
- qt5ct
- qt6ct
- ranger
- rofi
- swayidle
- swaylock
- wlogout
- zathura
- mimeapps.list
- user-dirs.dirs
- xdg-terminals.list

## Bootstrap

List components and package groups:

```bash
./bootstrap.sh --action list
```

Check repo relevance and compare with current live config:

```bash
./bootstrap.sh --action check
```

Dry-run a full install:

```bash
./bootstrap.sh --action install --dry-run
```

Minimal install:

```bash
./bootstrap.sh --action install --dry-run --package-preset minimal
```

Daily-driver install:

```bash
./bootstrap.sh --action install --dry-run --package-preset core
```

Full install with optional apps:

```bash
./bootstrap.sh --action install --dry-run --package-preset full
```

Preview full install including system login theme:

```bash
./bootstrap.sh --action install --dry-run --package-preset full --component sddm-theme --component sddm-config --component sddm-greeter
```

Hardware-aware install for another laptop:

```bash
./bootstrap.sh --action install --dry-run --hardware-profile laptop
```

Hardware-aware install with automatic UI density selection:

```bash
./bootstrap.sh --action install --dry-run --hardware-profile laptop --ui-density auto
```

Force a smaller or larger interface profile:

```bash
./bootstrap.sh --action install --dry-run --ui-density tiny
./bootstrap.sh --action install --dry-run --ui-density compact
./bootstrap.sh --action install --dry-run --ui-density large
./bootstrap.sh --action install --dry-run --ui-density huge
```

Show only hardware probe results before install:

```bash
./bootstrap.sh --probe-only
```

Override autodetection when needed:

```bash
./bootstrap.sh --action install --hardware-tag amd_gpu --skip-hardware-tag intel_gpu
```

Install selected components and an extra package group:

```bash
./bootstrap.sh --component niri --component rofi --package-group optional-gui
```

Use another compatible repo:

```bash
./bootstrap.sh --repo github-auto:cmdrJaponamat/dotfiles.git --action check
```

`install.sh` remains as a compatibility wrapper around `bootstrap.sh`.

## Current Theme Direction

- Base look: `gruvbox dark`
- GTK: `Gruvbox-Dark-BL`
- Qt icons: `Papirus-Dark`
- Qt theme engine: `Kvantum` with `Gruvbox-Dark-Brown`
- Custom surfaces: `waybar`, `rofi`, `mako`, `swaylock` aligned to the same palette
- Display manager: `SDDM` theme `SilentSDDM` with `gruvbox.conf`

## Canonical Runtime

- Current compositor runtime target: `niri`
- `hypr` remains in the repo mainly as:
  - legacy compositor config
  - wallpaper asset store
  - older helper scripts still being phased out
- New runtime-facing changes should prefer `niri/*` and `bin/*`
- `niri` runtime уже смотрит сначала в `niri/*`, а к `hypr/*` обращается только как к fallback для legacy-обоев и старого `rgb`

## Autostart Policy

- Канонический runtime-автозапуск сессии живёт в `niri/autostart.sh`
- XDG autostart overrides живут в `autostart/`
- В репозитории сейчас явно отключены:
  - `remmina-applet`
  - `slimbookbattery-autostart`
  - `blueman`
  - `org.fcitx.Fcitx5`
- Это убирает дубли и неожиданные фоновые индикаторы после развёртывания на новой машине

## UI Density

`bootstrap.sh` can now choose a UI density profile automatically from detected display modes.

- `tiny`: minimum profile for very dense small displays
- `compact`: smaller fonts and tighter UI
- `normal`: default profile
- `large`: larger fonts and controls for high-resolution displays
- `huge`: maximum profile for very large or very dense displays

The profile currently adjusts:

- `alacritty`
- `GTK 3/4`
- `qt5ct` and `qt6ct`
- `rofi`
- `waybar` for `niri`
- `mako`
- `swaylock`
- `wlogout`
- `zathura`
- `SilentSDDM` `gruvbox.conf`

For `waybar`, density also controls text pressure for long modules so the bar stays usable on laptop-width screens:

- `network` max text length
- `playerctl` max text length
- `playerctl` minimum reserved width

Runtime switching on the current machine:

```bash
~/.local/bin/ui-density up
~/.local/bin/ui-density down
~/.local/bin/ui-density auto
~/.local/bin/ui-density tiny
~/.local/bin/ui-density huge
```

Default `niri` hotkeys:

```text
Mod+Ctrl+=   increase density
Mod+Ctrl+-   decrease density
Mod+Ctrl+BackSpace   auto profile
```

## Session Menu

- Power menu: `~/.local/bin/power-menu`
  - uses `wlogout`
- Logout helper for `niri`: `~/.local/bin/session-logout`
- Default hotkey in `niri`: `Mod+Shift+P`
- Monitor power-off moved to: `Mod+Ctrl+P`

## SDDM

`SDDM` is a system-level component, so theme files install outside `$HOME`.

Dry-run only:

```bash
./bootstrap.sh --action install --dry-run --component sddm-theme --component sddm-config --component sddm-greeter --package-group display-manager
```

Real install:

```bash
sudo ./bootstrap.sh --action install --component sddm-theme --component sddm-config --component sddm-greeter --package-group display-manager --packages never --yes --target-home /
```

Optional theme preview before restarting `SDDM`:

```bash
cd /usr/share/sddm/themes/silent
sudo ./test.sh
```

Apply safely:

```bash
sudo reboot
```

`sudo systemctl restart sddm` from the active graphical session may leave login in a broken state on some setups. If a live restart is really needed, do it from a separate TTY instead of from inside the running desktop session.
