# dotfiles

Personal dotfiles for Arch Linux Wayland setup.

## Included
- alacritty
- btop
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

Hardware-aware install for another laptop:

```bash
./bootstrap.sh --action install --dry-run --hardware-profile laptop
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

## Session Menu

- Power menu: `~/.local/bin/power-menu`
- Logout helper for `niri`: `~/.local/bin/session-logout`
- Default hotkey in `niri`: `Mod+Shift+P`
- Monitor power-off moved to: `Mod+Ctrl+P`
