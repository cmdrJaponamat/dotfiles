#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_MANIFEST="${SCRIPT_DIR}/manifest/default.manifest.sh"

usage() {
  cat <<'EOF'
Usage:
  ./bootstrap.sh [options]

Options:
  --action check|install|list
  --repo PATH_OR_URL
  --manifest PATH
  --target-home PATH
  --component NAME
  --skip-component NAME
  --package-group NAME
  --skip-package-group NAME
  --package-preset minimal|core|full
  --extra-packages "pkg1 pkg2"
  --packages auto|always|never
  --hardware-tag TAG
  --skip-hardware-tag TAG
  --hardware-profile auto|desktop|laptop
  --ui-density auto|tiny|compact|normal|large|huge
  --probe-only
  --dry-run
  --yes
  --help

Examples:
  ./bootstrap.sh --action check
  ./bootstrap.sh --action install --dry-run
  ./bootstrap.sh --repo https://example.com/dotfiles.git --action check
  ./bootstrap.sh --component niri --component rofi --package-group optional-gui
  ./bootstrap.sh --hardware-profile laptop --hardware-tag amd_gpu
  ./bootstrap.sh --ui-density huge
EOF
}

ACTION="install"
REPO_INPUT="${SCRIPT_DIR}"
MANIFEST_PATH=""
TARGET_HOME="${HOME}"
PACKAGE_MODE="auto"
DRY_RUN=0
ASSUME_YES=0
EXTRA_PACKAGES=()
EXTRA_HARDWARE_TAGS=()
SKIPPED_HARDWARE_TAGS=()
SELECTED_COMPONENTS=()
SKIPPED_COMPONENTS=()
SELECTED_PACKAGE_GROUPS=()
SKIPPED_PACKAGE_GROUPS=()
PACKAGE_PRESET=""
HARDWARE_PROFILE="auto"
PROBE_ONLY=0
UI_DENSITY="auto"
ACTIVE_UI_DENSITY=""

declare -a DETECTED_HARDWARE_TAGS=()
declare -a HARDWARE_FACTS=()
declare -a HARDWARE_PROBE_NOTES=()
declare -a HARDWARE_PROBE_RECOMMENDATIONS=()
declare -A PROBE_METRICS=()
declare -A UI_PROFILE=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:?missing action}"
      shift 2
      ;;
    --repo)
      REPO_INPUT="${2:?missing repo}"
      shift 2
      ;;
    --manifest)
      MANIFEST_PATH="${2:?missing manifest path}"
      shift 2
      ;;
    --target-home)
      TARGET_HOME="${2:?missing target home}"
      shift 2
      ;;
    --component)
      SELECTED_COMPONENTS+=("${2:?missing component}")
      shift 2
      ;;
    --skip-component)
      SKIPPED_COMPONENTS+=("${2:?missing component}")
      shift 2
      ;;
    --package-group)
      SELECTED_PACKAGE_GROUPS+=("${2:?missing package group}")
      shift 2
      ;;
    --skip-package-group)
      SKIPPED_PACKAGE_GROUPS+=("${2:?missing package group}")
      shift 2
      ;;
    --package-preset)
      PACKAGE_PRESET="${2:?missing package preset}"
      shift 2
      ;;
    --extra-packages)
      read -r -a extra <<< "${2:?missing extra packages}"
      EXTRA_PACKAGES+=("${extra[@]}")
      shift 2
      ;;
    --packages)
      PACKAGE_MODE="${2:?missing package mode}"
      shift 2
      ;;
    --hardware-tag)
      EXTRA_HARDWARE_TAGS+=("${2:?missing hardware tag}")
      shift 2
      ;;
    --skip-hardware-tag)
      SKIPPED_HARDWARE_TAGS+=("${2:?missing hardware tag}")
      shift 2
      ;;
    --hardware-profile)
      HARDWARE_PROFILE="${2:?missing hardware profile}"
      shift 2
      ;;
    --ui-density)
      UI_DENSITY="${2:?missing ui density}"
      shift 2
      ;;
    --probe-only)
      PROBE_ONLY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

cleanup() {
  if [[ -n "${TEMP_REPO_DIR:-}" && -d "${TEMP_REPO_DIR}" ]]; then
    rm -rf "${TEMP_REPO_DIR}"
  fi
}
trap cleanup EXIT

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

join_by() {
  local delimiter="$1"
  shift
  local first=1
  local item
  for item in "$@"; do
    if (( first )); then
      printf '%s' "${item}"
      first=0
    else
      printf '%s%s' "${delimiter}" "${item}"
    fi
  done
}

resolve_dest_path() {
  local dest="$1"
  if [[ "${dest}" == /* ]]; then
    printf '%s\n' "${dest}"
  else
    printf '%s\n' "${TARGET_HOME}/${dest}"
  fi
}

component_selected() {
  local wanted="$1"
  local row name src dest mode desc
  for row in "${ACTIVE_COMPONENT_ROWS[@]:-}"; do
    IFS='|' read -r name src dest mode desc <<< "${row}"
    [[ "${name}" == "${wanted}" ]] && return 0
  done
  return 1
}

optional_flow_matches_hardware() {
  local selector="$1"
  case "${selector}" in
    ""|"always")
      return 0
      ;;
  esac

  local required
  read -r -a required <<< "${selector}"
  local tag
  for tag in "${required[@]}"; do
    contains "${tag}" "${DETECTED_HARDWARE_TAGS[@]:-}" && return 0
  done
  return 1
}

resolve_repo() {
  local input="$1"
  if [[ -d "${input}" ]]; then
    REPO_DIR="$(cd -- "${input}" && pwd)"
    return
  fi

  if [[ "${input}" =~ ^(https://|git@|ssh://|github-auto:).+\.git$ ]]; then
    command -v git >/dev/null 2>&1 || die "git is required to clone ${input}"
    TEMP_REPO_DIR="$(mktemp -d)"
    log "Cloning ${input} into ${TEMP_REPO_DIR}"
    git clone --depth 1 "${input}" "${TEMP_REPO_DIR}" >/dev/null
    REPO_DIR="${TEMP_REPO_DIR}"
    return
  fi

  die "Repo input must be a directory or git URL: ${input}"
}

load_manifest() {
  local repo_dir="$1"
  local manifest_path="${MANIFEST_PATH}"
  if [[ -z "${manifest_path}" ]]; then
    manifest_path="${repo_dir}/manifest/default.manifest.sh"
  elif [[ "${manifest_path}" != /* ]]; then
    manifest_path="${repo_dir}/${manifest_path}"
  fi

  [[ -f "${manifest_path}" ]] || die "Manifest not found: ${manifest_path}"
  # shellcheck disable=SC1090
  source "${manifest_path}"
  ACTIVE_MANIFEST_PATH="${manifest_path}"
}

validate_manifest() {
  [[ -n "${DOTBOOTSTRAP_NAME:-}" ]] || die "Manifest missing DOTBOOTSTRAP_NAME"
  [[ -v DOTBOOTSTRAP_COMPONENTS ]] || die "Manifest has no DOTBOOTSTRAP_COMPONENTS array"
  [[ "${#DOTBOOTSTRAP_COMPONENTS[@]}" -gt 0 ]] || die "Manifest has no components"
}

add_hardware_tag() {
  local tag="$1"
  [[ -n "${tag}" ]] || return 0
  contains "${tag}" "${DETECTED_HARDWARE_TAGS[@]:-}" || DETECTED_HARDWARE_TAGS+=("${tag}")
}

add_fact() {
  local fact="$1"
  [[ -n "${fact}" ]] || return 0
  HARDWARE_FACTS+=("${fact}")
}

add_probe_note() {
  local note="$1"
  [[ -n "${note}" ]] || return 0
  HARDWARE_PROBE_NOTES+=("${note}")
}

add_probe_recommendation() {
  local rec="$1"
  [[ -n "${rec}" ]] || return 0
  HARDWARE_PROBE_RECOMMENDATIONS+=("${rec}")
}

set_probe_metric() {
  local key="$1"
  local value="$2"
  [[ -n "${key}" && -n "${value}" ]] || return 0
  PROBE_METRICS["${key}"]="${value}"
}

set_ui_value() {
  local key="$1"
  local value="$2"
  [[ -n "${key}" && -n "${value}" ]] || return 0
  UI_PROFILE["${key}"]="${value}"
}

detect_display_profile() {
  local best_width=0
  local best_height=0
  local mode_file line width height area best_area=0

  while IFS= read -r -d '' mode_file; do
    while IFS= read -r line; do
      [[ "${line}" =~ ^([0-9]+)x([0-9]+)$ ]] || continue
      width="${BASH_REMATCH[1]}"
      height="${BASH_REMATCH[2]}"
      area=$(( width * height ))
      if (( area > best_area )); then
        best_area="${area}"
        best_width="${width}"
        best_height="${height}"
      fi
    done < "${mode_file}"
  done < <(find /sys/class/drm -path "*/modes" -print0 2>/dev/null)

  if (( best_width > 0 && best_height > 0 )); then
    set_probe_metric "display_width" "${best_width}"
    set_probe_metric "display_height" "${best_height}"
    add_fact "max_mode=${best_width}x${best_height}"
  fi
}

resolve_ui_density() {
  local density="${UI_DENSITY}"
  local width="${PROBE_METRICS[display_width]:-0}"
  local height="${PROBE_METRICS[display_height]:-0}"

  if [[ "${density}" == "auto" ]]; then
    if (( height >= 1800 || width >= 3200 )); then
      density="huge"
    elif (( height >= 1440 || width >= 2560 )); then
      density="large"
    elif (( height > 0 && height <= 800 )); then
      density="tiny"
    elif (( height > 0 && height <= 1080 )); then
      density="compact"
    else
      density="normal"
    fi
  fi

  case "${density}" in
    tiny|compact|normal|large|huge)
      ;;
    *)
      die "Unsupported ui density: ${density}"
      ;;
  esac

  ACTIVE_UI_DENSITY="${density}"

  case "${density}" in
    tiny)
      set_ui_value "alacritty_font_size" "10.0"
      set_ui_value "gtk_font_size" "9"
      set_ui_value "qt_font_size" "9"
      set_ui_value "rofi_font_size" "10"
      set_ui_value "waybar_font_size" "8pt"
      set_ui_value "waybar_network_max_length" "13"
      set_ui_value "waybar_playerctl_max_length" "16"
      set_ui_value "waybar_playerctl_min_length" "0"
      set_ui_value "mako_font_size" "10"
      set_ui_value "mako_width" "320"
      set_ui_value "mako_padding" "10"
      set_ui_value "swaylock_indicator_radius" "82"
      set_ui_value "swaylock_indicator_thickness" "9"
      set_ui_value "wlogout_font_size" "14px"
      set_ui_value "zathura_font_size" "10"
      set_ui_value "sddm_scale" "0.92"
      set_ui_value "sddm_clock_font_size" "64"
      set_ui_value "sddm_date_font_size" "14"
      set_ui_value "sddm_message_font_size" "12"
      set_ui_value "sddm_username_font_size" "18"
      set_ui_value "sddm_password_width" "228"
      set_ui_value "sddm_password_height" "34"
      set_ui_value "sddm_password_font_size" "13"
      set_ui_value "sddm_button_font_size" "12"
      set_ui_value "sddm_spinner_font_size" "14"
      set_ui_value "sddm_warning_font_size" "11"
      set_ui_value "sddm_menu_button_size" "28"
      set_ui_value "sddm_popup_font_size" "12"
      set_ui_value "sddm_session_button_width" "200"
      set_ui_value "sddm_session_popup_width" "200"
      set_ui_value "sddm_session_font_size" "11"
      set_ui_value "sddm_layout_popup_width" "180"
      set_ui_value "sddm_layout_font_size" "11"
      set_ui_value "sddm_virtual_keyboard_scale" "0.92"
      ;;
    compact)
      set_ui_value "alacritty_font_size" "11.0"
      set_ui_value "gtk_font_size" "10"
      set_ui_value "qt_font_size" "10"
      set_ui_value "rofi_font_size" "11"
      set_ui_value "waybar_font_size" "9pt"
      set_ui_value "waybar_network_max_length" "15"
      set_ui_value "waybar_playerctl_max_length" "18"
      set_ui_value "waybar_playerctl_min_length" "0"
      set_ui_value "mako_font_size" "11"
      set_ui_value "mako_width" "360"
      set_ui_value "mako_padding" "12"
      set_ui_value "swaylock_indicator_radius" "92"
      set_ui_value "swaylock_indicator_thickness" "10"
      set_ui_value "wlogout_font_size" "16px"
      set_ui_value "zathura_font_size" "11"
      set_ui_value "sddm_scale" "1.0"
      set_ui_value "sddm_clock_font_size" "72"
      set_ui_value "sddm_date_font_size" "16"
      set_ui_value "sddm_message_font_size" "13"
      set_ui_value "sddm_username_font_size" "20"
      set_ui_value "sddm_password_width" "250"
      set_ui_value "sddm_password_height" "38"
      set_ui_value "sddm_password_font_size" "14"
      set_ui_value "sddm_button_font_size" "13"
      set_ui_value "sddm_spinner_font_size" "16"
      set_ui_value "sddm_warning_font_size" "12"
      set_ui_value "sddm_menu_button_size" "32"
      set_ui_value "sddm_popup_font_size" "13"
      set_ui_value "sddm_session_button_width" "220"
      set_ui_value "sddm_session_popup_width" "220"
      set_ui_value "sddm_session_font_size" "12"
      set_ui_value "sddm_layout_popup_width" "200"
      set_ui_value "sddm_layout_font_size" "12"
      set_ui_value "sddm_virtual_keyboard_scale" "1.0"
      ;;
    normal)
      set_ui_value "alacritty_font_size" "12.0"
      set_ui_value "gtk_font_size" "11"
      set_ui_value "qt_font_size" "11"
      set_ui_value "rofi_font_size" "12"
      set_ui_value "waybar_font_size" "10pt"
      set_ui_value "waybar_network_max_length" "18"
      set_ui_value "waybar_playerctl_max_length" "24"
      set_ui_value "waybar_playerctl_min_length" "10"
      set_ui_value "mako_font_size" "12"
      set_ui_value "mako_width" "420"
      set_ui_value "mako_padding" "14"
      set_ui_value "swaylock_indicator_radius" "110"
      set_ui_value "swaylock_indicator_thickness" "12"
      set_ui_value "wlogout_font_size" "18px"
      set_ui_value "zathura_font_size" "12"
      set_ui_value "sddm_scale" "1.3"
      set_ui_value "sddm_clock_font_size" "88"
      set_ui_value "sddm_date_font_size" "18"
      set_ui_value "sddm_message_font_size" "15"
      set_ui_value "sddm_username_font_size" "22"
      set_ui_value "sddm_password_width" "280"
      set_ui_value "sddm_password_height" "42"
      set_ui_value "sddm_password_font_size" "16"
      set_ui_value "sddm_button_font_size" "15"
      set_ui_value "sddm_spinner_font_size" "18"
      set_ui_value "sddm_warning_font_size" "14"
      set_ui_value "sddm_menu_button_size" "36"
      set_ui_value "sddm_popup_font_size" "14"
      set_ui_value "sddm_session_button_width" "240"
      set_ui_value "sddm_session_popup_width" "240"
      set_ui_value "sddm_session_font_size" "13"
      set_ui_value "sddm_layout_popup_width" "220"
      set_ui_value "sddm_layout_font_size" "13"
      set_ui_value "sddm_virtual_keyboard_scale" "1.15"
      ;;
    large)
      set_ui_value "alacritty_font_size" "14.0"
      set_ui_value "gtk_font_size" "13"
      set_ui_value "qt_font_size" "13"
      set_ui_value "rofi_font_size" "14"
      set_ui_value "waybar_font_size" "11pt"
      set_ui_value "waybar_network_max_length" "18"
      set_ui_value "waybar_playerctl_max_length" "24"
      set_ui_value "waybar_playerctl_min_length" "8"
      set_ui_value "mako_font_size" "14"
      set_ui_value "mako_width" "520"
      set_ui_value "mako_padding" "16"
      set_ui_value "swaylock_indicator_radius" "128"
      set_ui_value "swaylock_indicator_thickness" "14"
      set_ui_value "wlogout_font_size" "22px"
      set_ui_value "zathura_font_size" "14"
      set_ui_value "sddm_scale" "1.55"
      set_ui_value "sddm_clock_font_size" "108"
      set_ui_value "sddm_date_font_size" "22"
      set_ui_value "sddm_message_font_size" "18"
      set_ui_value "sddm_username_font_size" "26"
      set_ui_value "sddm_password_width" "340"
      set_ui_value "sddm_password_height" "50"
      set_ui_value "sddm_password_font_size" "19"
      set_ui_value "sddm_button_font_size" "18"
      set_ui_value "sddm_spinner_font_size" "22"
      set_ui_value "sddm_warning_font_size" "16"
      set_ui_value "sddm_menu_button_size" "42"
      set_ui_value "sddm_popup_font_size" "16"
      set_ui_value "sddm_session_button_width" "280"
      set_ui_value "sddm_session_popup_width" "280"
      set_ui_value "sddm_session_font_size" "15"
      set_ui_value "sddm_layout_popup_width" "250"
      set_ui_value "sddm_layout_font_size" "15"
      set_ui_value "sddm_virtual_keyboard_scale" "1.3"
      ;;
    huge)
      set_ui_value "alacritty_font_size" "16.0"
      set_ui_value "gtk_font_size" "15"
      set_ui_value "qt_font_size" "15"
      set_ui_value "rofi_font_size" "16"
      set_ui_value "waybar_font_size" "11pt"
      set_ui_value "waybar_network_max_length" "16"
      set_ui_value "waybar_playerctl_max_length" "18"
      set_ui_value "waybar_playerctl_min_length" "0"
      set_ui_value "mako_font_size" "16"
      set_ui_value "mako_width" "620"
      set_ui_value "mako_padding" "18"
      set_ui_value "swaylock_indicator_radius" "148"
      set_ui_value "swaylock_indicator_thickness" "16"
      set_ui_value "wlogout_font_size" "26px"
      set_ui_value "zathura_font_size" "16"
      set_ui_value "sddm_scale" "1.8"
      set_ui_value "sddm_clock_font_size" "124"
      set_ui_value "sddm_date_font_size" "26"
      set_ui_value "sddm_message_font_size" "20"
      set_ui_value "sddm_username_font_size" "30"
      set_ui_value "sddm_password_width" "390"
      set_ui_value "sddm_password_height" "56"
      set_ui_value "sddm_password_font_size" "21"
      set_ui_value "sddm_button_font_size" "20"
      set_ui_value "sddm_spinner_font_size" "24"
      set_ui_value "sddm_warning_font_size" "17"
      set_ui_value "sddm_menu_button_size" "48"
      set_ui_value "sddm_popup_font_size" "18"
      set_ui_value "sddm_session_button_width" "320"
      set_ui_value "sddm_session_popup_width" "320"
      set_ui_value "sddm_session_font_size" "17"
      set_ui_value "sddm_layout_popup_width" "290"
      set_ui_value "sddm_layout_font_size" "17"
      set_ui_value "sddm_virtual_keyboard_scale" "1.45"
      ;;
  esac
}

replace_or_warn() {
  local file="$1"
  local replacement="$2"

  [[ -f "${file}" ]] || return 0
  if ! perl -0pi -e "${replacement}" "${file}"; then
    warn "failed to update ${file}"
  fi
}

apply_ui_profile() {
  local target_home="$1"
  local config_home="${target_home}/.config"
  local local_bin="${target_home}/.local/bin"
  local alacritty_file="${config_home}/alacritty/alacritty.toml"
  local gtk3_file="${config_home}/gtk-3.0/settings.ini"
  local gtk4_file="${config_home}/gtk-4.0/settings.ini"
  local qt5_file="${config_home}/qt5ct/qt5ct.conf"
  local qt6_file="${config_home}/qt6ct/qt6ct.conf"
  local rofi_file="${config_home}/rofi/config.rasi"
  local waybar_file="${config_home}/niri/waybar/style.css"
  local waybar_config_file="${config_home}/niri/waybar/config"
  local mako_file="${config_home}/mako/config"
  local swaylock_file="${config_home}/swaylock/config"
  local wlogout_file="${config_home}/wlogout/style.css"
  local zathura_file="${config_home}/zathura/zathurarc"
  local silent_file="/usr/share/sddm/themes/silent/configs/gruvbox.conf"

  replace_or_warn "${alacritty_file}" "s/^size = .*\$/size = ${UI_PROFILE[alacritty_font_size]}/m"
  replace_or_warn "${gtk3_file}" "s/^gtk-font-name=.*\$/gtk-font-name=JetBrains Mono ${UI_PROFILE[gtk_font_size]}/m"
  replace_or_warn "${gtk4_file}" "s/^gtk-font-name=.*\$/gtk-font-name=JetBrains Mono ${UI_PROFILE[gtk_font_size]}/m"
  replace_or_warn "${qt5_file}" "s/^fixed=.*\$/fixed=\"JetBrains Mono,${UI_PROFILE[qt_font_size]},-1,5,50,0,0,0,0,0,Regular\"/m; s/^general=.*\$/general=\"JetBrains Mono,${UI_PROFILE[qt_font_size]},-1,5,50,0,0,0,0,0,Regular\"/m"
  replace_or_warn "${qt6_file}" "s/^fixed=.*\$/fixed=\"JetBrains Mono,${UI_PROFILE[qt_font_size]},-1,5,50,0,0,0,0,0,Regular\"/m; s/^general=.*\$/general=\"JetBrains Mono,${UI_PROFILE[qt_font_size]},-1,5,50,0,0,0,0,0,Regular\"/m"
  replace_or_warn "${rofi_file}" "s/font: \"JetBrains Mono Nerd Font [0-9]+\";/font: \"JetBrains Mono Nerd Font ${UI_PROFILE[rofi_font_size]}\";/m"
  replace_or_warn "${waybar_file}" "s/font-size:\\s*[0-9]+pt;/font-size: ${UI_PROFILE[waybar_font_size]};/m"
  replace_or_warn "${waybar_config_file}" "s/(\"network\":\\s*\\{.*?\"max-length\":\\s*)\\d+/\${1}${UI_PROFILE[waybar_network_max_length]}/s; s/(\"custom\\/playerctl\":\\s*\\{.*?\"max-length\":\\s*)\\d+/\${1}${UI_PROFILE[waybar_playerctl_max_length]}/s; s/(\"custom\\/playerctl\":\\s*\\{.*?\"min-length\":\\s*)\\d+/\${1}${UI_PROFILE[waybar_playerctl_min_length]}/s"
  replace_or_warn "${mako_file}" "s/^font=.*/font=JetBrains Mono Nerd Font ${UI_PROFILE[mako_font_size]}/m; s/^width=.*/width=${UI_PROFILE[mako_width]}/m; s/^padding=.*/padding=${UI_PROFILE[mako_padding]}/m"
  replace_or_warn "${swaylock_file}" "s/^indicator-radius=.*/indicator-radius=${UI_PROFILE[swaylock_indicator_radius]}/m; s/^indicator-thickness=.*/indicator-thickness=${UI_PROFILE[swaylock_indicator_thickness]}/m"
  replace_or_warn "${wlogout_file}" "s/font-size:\\s*[0-9]+px;/font-size: ${UI_PROFILE[wlogout_font_size]};/m"
  replace_or_warn "${zathura_file}" "s/set font\\s+\"JetBrainsMono Nerd Font [0-9]+\"/set font                    \"JetBrainsMono Nerd Font ${UI_PROFILE[zathura_font_size]}\"/m"

  if [[ -f "${silent_file}" ]]; then
    replace_or_warn "${silent_file}" '
      s/^scale = .*$/'"scale = ${UI_PROFILE[sddm_scale]}"'/m;
      s/(\\[LockScreen\\.Clock\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_clock_font_size]}"'/;
      s/(\\[LockScreen\\.Date\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_date_font_size]}"'/;
      s/(\\[LockScreen\\.Message\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_message_font_size]}"'/;
      s/(\\[LoginScreen\\.LoginArea\\.Username\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_username_font_size]}"'/;
      s/(\\[LoginScreen\\.LoginArea\\.PasswordInput\\]\\n(?:.*\\n)*?width = )\\d+/${1}'"${UI_PROFILE[sddm_password_width]}"'/;
      s/(\\[LoginScreen\\.LoginArea\\.PasswordInput\\]\\n(?:.*\\n)*?height = )\\d+/${1}'"${UI_PROFILE[sddm_password_height]}"'/;
      s/(\\[LoginScreen\\.LoginArea\\.PasswordInput\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_password_font_size]}"'/;
      s/(\\[LoginScreen\\.LoginArea\\.LoginButton\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_button_font_size]}"'/;
      s/(\\[LoginScreen\\.LoginArea\\.Spinner\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_spinner_font_size]}"'/;
      s/(\\[LoginScreen\\.LoginArea\\.WarningMessage\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_warning_font_size]}"'/;
      s/(\\[LoginScreen\\.MenuArea\\.Buttons\\]\\n(?:.*\\n)*?size = )\\d+/${1}'"${UI_PROFILE[sddm_menu_button_size]}"'/;
      s/(\\[LoginScreen\\.MenuArea\\.Popups\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_popup_font_size]}"'/;
      s/(\\[LoginScreen\\.MenuArea\\.Session\\]\\n(?:.*\\n)*?button-width = )\\d+/${1}'"${UI_PROFILE[sddm_session_button_width]}"'/;
      s/(\\[LoginScreen\\.MenuArea\\.Session\\]\\n(?:.*\\n)*?popup-width = )\\d+/${1}'"${UI_PROFILE[sddm_session_popup_width]}"'/;
      s/(\\[LoginScreen\\.MenuArea\\.Session\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_session_font_size]}"'/;
      s/(\\[LoginScreen\\.MenuArea\\.Layout\\]\\n(?:.*\\n)*?popup-width = )\\d+/${1}'"${UI_PROFILE[sddm_layout_popup_width]}"'/;
      s/(\\[LoginScreen\\.MenuArea\\.Layout\\]\\n(?:.*\\n)*?font-size = )\\d+/${1}'"${UI_PROFILE[sddm_layout_font_size]}"'/;
      s/(\\[LoginScreen\\.VirtualKeyboard\\]\\n(?:.*\\n)*?scale = )[^\\n]+/${1}'"${UI_PROFILE[sddm_virtual_keyboard_scale]}"'/;
    '
  fi
}

detect_hardware_tags() {
  PROBE_METRICS=()
  DETECTED_HARDWARE_TAGS=()
  HARDWARE_FACTS=()
  HARDWARE_PROBE_NOTES=()
  HARDWARE_PROBE_RECOMMENDATIONS=()

  case "${HARDWARE_PROFILE}" in
    laptop)
      add_hardware_tag "laptop"
      add_hardware_tag "battery"
      ;;
    desktop)
      add_hardware_tag "desktop"
      ;;
    auto)
      ;;
    *)
      die "Unsupported hardware profile: ${HARDWARE_PROFILE}"
      ;;
  esac

  if [[ "${HARDWARE_PROFILE}" == "auto" ]]; then
    if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
      add_hardware_tag "battery"
      add_hardware_tag "laptop"
      add_fact "battery_present"
    fi
    if compgen -G "/sys/class/backlight/*" >/dev/null; then
      add_hardware_tag "backlight"
      add_fact "backlight_present"
    fi
    if compgen -G "/sys/class/net/wl*" >/dev/null; then
      add_hardware_tag "wifi"
      add_fact "wifi_present"
    fi
    if [[ -d /sys/class/bluetooth ]] || compgen -G "/sys/class/rfkill/rfkill*" >/dev/null; then
      add_hardware_tag "bluetooth"
      add_fact "bluetooth_present"
    fi
    if rg -qi "touchpad|trackpoint" /proc/bus/input/devices 2>/dev/null; then
      add_hardware_tag "touchpad"
      add_hardware_tag "laptop"
      add_fact "touchpad_present"
    fi
    if rg -qi "touchscreen|touch screen|touch digitizer" /proc/bus/input/devices 2>/dev/null; then
      add_hardware_tag "touchscreen"
      add_fact "touchscreen_present"
    fi
    if compgen -G "/sys/class/drm/card*-eDP-*" >/dev/null; then
      add_hardware_tag "internal_display"
      add_hardware_tag "laptop"
      add_fact "internal_display_present"
    fi
  fi

  if lspci 2>/dev/null | rg -qi "vga|3d|display"; then
    if lspci 2>/dev/null | rg -qi "intel"; then
      add_hardware_tag "intel_gpu"
      add_fact "intel_gpu_present"
    fi
    if lspci 2>/dev/null | rg -qi "amd|ati"; then
      add_hardware_tag "amd_gpu"
      add_fact "amd_gpu_present"
    fi
    if lspci 2>/dev/null | rg -qi "nvidia"; then
      add_hardware_tag "nvidia_gpu"
      add_fact "nvidia_gpu_present"
    fi
  fi

  if ! contains "laptop" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    add_hardware_tag "desktop"
  fi

  local tag
  for tag in "${EXTRA_HARDWARE_TAGS[@]}"; do
    add_hardware_tag "${tag}"
  done

  if [[ "${#SKIPPED_HARDWARE_TAGS[@]}" -gt 0 ]]; then
    local filtered=()
    for tag in "${DETECTED_HARDWARE_TAGS[@]}"; do
      contains "${tag}" "${SKIPPED_HARDWARE_TAGS[@]}" || filtered+=("${tag}")
    done
    DETECTED_HARDWARE_TAGS=("${filtered[@]}")
  fi

  build_probe_recommendations
}

build_probe_recommendations() {
  if contains "touchscreen" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    add_probe_note "touchscreen detected"
    add_probe_recommendation "Review touchscreen toggle integration after install: niri Waybar module or bind/unbind helper may be useful."
  fi

  if contains "laptop" "${DETECTED_HARDWARE_TAGS[@]:-}" && ! contains "battery" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    add_probe_note "laptop-like input/display detected without battery fact"
    add_probe_recommendation "Verify power-management choice manually; battery device was not detected during probe."
  fi

  if contains "nvidia_gpu" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    add_probe_recommendation "Add an NVIDIA-specific package group before using this setup on proprietary NVIDIA laptops."
  fi

  if contains "intel_gpu" "${DETECTED_HARDWARE_TAGS[@]:-}" && contains "amd_gpu" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    add_probe_note "multiple GPU vendors detected"
    add_probe_recommendation "Review hybrid-graphics needs; current manifest may install both Intel and AMD userland."
  fi

  if contains "backlight" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    add_probe_recommendation "Keep brightness wrappers enabled; this machine exposes a backlight device."
  fi

  if contains "wifi" "${DETECTED_HARDWARE_TAGS[@]:-}" || contains "bluetooth" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    add_probe_recommendation "Check whether NetworkManager and Bluetooth services should be enabled as part of first boot on the new machine."
  fi
}

print_probe_summary() {
  log
  log "Hardware tags: $(join_by ', ' "${DETECTED_HARDWARE_TAGS[@]}")"

  if [[ "${#HARDWARE_FACTS[@]}" -gt 0 ]]; then
    log "Hardware facts:"
    local fact
    for fact in "${HARDWARE_FACTS[@]}"; do
      log "  ${fact}"
    done
  fi

  if [[ "${#HARDWARE_PROBE_NOTES[@]}" -gt 0 ]]; then
    log "Probe notes:"
    local note
    for note in "${HARDWARE_PROBE_NOTES[@]}"; do
      log "  ${note}"
    done
  fi

  if [[ "${#HARDWARE_PROBE_RECOMMENDATIONS[@]}" -gt 0 ]]; then
    log "Probe recommendations:"
    local recommendation
    for recommendation in "${HARDWARE_PROBE_RECOMMENDATIONS[@]}"; do
      log "  ${recommendation}"
    done
  fi

  if [[ -n "${ACTIVE_UI_DENSITY}" ]]; then
    log "UI density: ${ACTIVE_UI_DENSITY}"
  fi
}

print_post_install_steps() {
  log
  log "Post-install:"

  if component_selected "niri" || component_selected "waybar"; then
    log "  Relogin into the session so autostart, Waybar, mako and user config reload cleanly."
  fi

  if component_selected "autostart"; then
    log "  Review ~/.config/autostart if this machine should re-enable Telegram, Blueman, fcitx5 or other tray apps."
  fi

  if component_selected "sddm-theme" || component_selected "sddm-config" || component_selected "sddm-greeter"; then
    log "  Reboot after SDDM changes instead of restarting sddm from the running graphical session."
    log "  Optional preview before reboot: cd /usr/share/sddm/themes/silent && sudo ./test.sh"
  fi

  if contains "wifi" "${DETECTED_HARDWARE_TAGS[@]:-}" || contains "bluetooth" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    log "  Ensure NetworkManager and Bluetooth services are enabled if this laptop depends on them."
  fi

  if contains "battery" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    log "  Review power-management choice after first boot: TLP is included, Slimbook Battery stays optional."
  fi

  if contains "touchscreen" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    log "  Test touchscreen toggle and input mapping after first login."
  fi

  if contains "nvidia_gpu" "${DETECTED_HARDWARE_TAGS[@]:-}"; then
    log "  NVIDIA detected: add proprietary driver flow manually before treating the install as complete."
  fi

  if [[ "${UI_DENSITY}" == "auto" ]]; then
    :
  else
    log "  UI density was forced to ${ACTIVE_UI_DENSITY}; adjust later with ~/.local/bin/ui-density if needed."
  fi

  if [[ -v DOTBOOTSTRAP_OPTIONAL_FLOWS ]] && [[ "${#DOTBOOTSTRAP_OPTIONAL_FLOWS[@]}" -gt 0 ]]; then
    log
    log "Optional flows:"
    local row name selector summary details
    for row in "${DOTBOOTSTRAP_OPTIONAL_FLOWS[@]:-}"; do
      IFS='|' read -r name selector summary details <<< "${row}"
      optional_flow_matches_hardware "${selector}" || continue
      log "  ${name}: ${summary}"
      [[ -n "${details}" ]] && log "    ${details}"
    done
  fi
}

package_group_matches_hardware() {
  local selector="$1"
  case "${selector}" in
    ""|"always")
      return 0
      ;;
  esac

  local required
  read -r -a required <<< "${selector}"
  local tag
  for tag in "${required[@]}"; do
    contains "${tag}" "${DETECTED_HARDWARE_TAGS[@]:-}" && return 0
  done
  return 1
}

resolve_package_preset() {
  local preset_name="${PACKAGE_PRESET:-${DOTBOOTSTRAP_DEFAULT_PACKAGE_PRESET:-}}"
  [[ -n "${preset_name}" ]] || return 0

  local unresolved=("${preset_name}")
  ACTIVE_PACKAGE_PRESET_GROUPS=()
  local seen=()
  local current row name items desc item found

  while [[ "${#unresolved[@]}" -gt 0 ]]; do
    current="${unresolved[0]}"
    unresolved=("${unresolved[@]:1}")
    contains "${current}" "${seen[@]}" && continue
    seen+=("${current}")

    found=0
    for row in "${DOTBOOTSTRAP_PACKAGE_PRESETS[@]:-}"; do
      IFS='|' read -r name items desc <<< "${row}"
      if [[ "${name}" == "${current}" ]]; then
        found=1
        read -r -a parsed_items <<< "${items}"
        for item in "${parsed_items[@]}"; do
          if contains "${item}" "${seen[@]}"; then
            continue
          fi
          if preset_exists "${item}"; then
            unresolved+=("${item}")
          else
            contains "${item}" "${ACTIVE_PACKAGE_PRESET_GROUPS[@]:-}" || ACTIVE_PACKAGE_PRESET_GROUPS+=("${item}")
          fi
        done
        break
      fi
    done

    (( found == 1 )) || die "Unknown package preset: ${current}"
  done
}

preset_exists() {
  local wanted="$1"
  local row name items desc
  for row in "${DOTBOOTSTRAP_PACKAGE_PRESETS[@]:-}"; do
    IFS='|' read -r name items desc <<< "${row}"
    [[ "${name}" == "${wanted}" ]] && return 0
  done
  return 1
}

detect_package_manager() {
  if command -v pacman >/dev/null 2>&1; then
    PACKAGE_MANAGER="pacman"
  elif command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
  elif command -v zypper >/dev/null 2>&1; then
    PACKAGE_MANAGER="zypper"
  else
    PACKAGE_MANAGER="unknown"
  fi
}

package_install_cmd() {
  local packages=("$@")
  case "${PACKAGE_MANAGER}" in
    pacman)
      printf 'sudo pacman -S --needed %s' "$(join_by ' ' "${packages[@]}")"
      ;;
    apt)
      printf 'sudo apt-get install -y %s' "$(join_by ' ' "${packages[@]}")"
      ;;
    dnf)
      printf 'sudo dnf install -y %s' "$(join_by ' ' "${packages[@]}")"
      ;;
    zypper)
      printf 'sudo zypper install -y %s' "$(join_by ' ' "${packages[@]}")"
      ;;
    *)
      return 1
      ;;
  esac
}

collect_components() {
  local row name src dest mode desc
  ACTIVE_COMPONENT_ROWS=()
  for row in "${DOTBOOTSTRAP_COMPONENTS[@]}"; do
    IFS='|' read -r name src dest mode desc <<< "${row}"
    [[ -n "${name}" && -n "${src}" && -n "${dest}" && -n "${mode}" ]] || die "Bad component row: ${row}"
    [[ -e "${REPO_DIR}/${src}" ]] || die "Component source missing: ${src}"

    if contains "${name}" "${SKIPPED_COMPONENTS[@]}"; then
      continue
    fi

    if [[ "${#SELECTED_COMPONENTS[@]}" -gt 0 ]]; then
      contains "${name}" "${SELECTED_COMPONENTS[@]}" || continue
    else
      if [[ "${mode}" == "required" ]] || contains "${name}" "${DOTBOOTSTRAP_DEFAULT_COMPONENTS[@]:-}"; then
        :
      else
        continue
      fi
    fi

    ACTIVE_COMPONENT_ROWS+=("${row}")
  done

  [[ "${#ACTIVE_COMPONENT_ROWS[@]}" -gt 0 ]] || die "No components selected"
}

collect_packages() {
  ACTIVE_PACKAGE_GROUP_ROWS=()
  local row name tier selector packages desc
  for row in "${DOTBOOTSTRAP_PACKAGE_GROUPS[@]:-}"; do
    IFS='|' read -r name tier selector packages desc <<< "${row}"
    [[ -n "${name}" && -n "${tier}" && -n "${selector}" && -n "${packages}" ]] || die "Bad package group row: ${row}"

    if contains "${name}" "${SKIPPED_PACKAGE_GROUPS[@]}"; then
      continue
    fi

    if [[ "${#SELECTED_PACKAGE_GROUPS[@]}" -gt 0 ]]; then
      contains "${name}" "${SELECTED_PACKAGE_GROUPS[@]}" || continue
    else
      if contains "${name}" "${ACTIVE_PACKAGE_PRESET_GROUPS[@]:-}"; then
        package_group_matches_hardware "${selector}" || continue
      else
        continue
      fi
    fi

    ACTIVE_PACKAGE_GROUP_ROWS+=("${row}")
  done
}

run_relevance_check() {
  local status=0
  local row name src dest mode desc abs_src abs_dest
  local diff_excludes=(
    "-x" "*.bak"
    "-x" "*.log"
    "-x" "fish_variables"
    "-x" "__pycache__"
    "-x" "*.pyc"
  )

  log "Manifest: ${ACTIVE_MANIFEST_PATH}"
  log "Repo: ${REPO_DIR}"
  log "Target home: ${TARGET_HOME}"
  log "Hardware tags: $(join_by ', ' "${DETECTED_HARDWARE_TAGS[@]}")"
  log
  log "Component validation:"
  for row in "${ACTIVE_COMPONENT_ROWS[@]}"; do
    IFS='|' read -r name src dest mode desc <<< "${row}"
    abs_src="${REPO_DIR}/${src}"
    abs_dest="$(resolve_dest_path "${dest}")"
    if [[ -e "${abs_src}" ]]; then
      log "  OK  ${name}: ${src} -> ${dest}"
    else
      log "  FAIL ${name}: missing ${src}"
      status=1
    fi

    if [[ -e "${abs_dest}" ]]; then
      if diff -qr "${diff_excludes[@]}" "${abs_src}" "${abs_dest}" >/dev/null 2>&1; then
        log "      live: in sync"
      else
        log "      live: differs from ${dest}"
      fi
    else
      log "      live: target missing"
    fi
  done

  log
  log "Relevance warnings:"
  local pattern
  local warned=0
  for pattern in "${DOTBOOTSTRAP_RELEVANCE_WARN_PATTERNS[@]:-}"; do
    if rg -n --fixed-strings "${pattern}" "${REPO_DIR}" \
      -g '!**/.git/**' \
      -g '!**/bk/**' \
      -g '!**/*.zip' \
      -g '!manifest/default.manifest.sh' \
      >/tmp/dotbootstrap_warn.$$ 2>/dev/null; then
      warn "pattern '${pattern}' found in repo:"
      sed 's/^/  /' "/tmp/dotbootstrap_warn.$$"
      warned=1
    fi
  done
  rm -f "/tmp/dotbootstrap_warn.$$"

  if (( warned == 0 )); then
    log "  no known portability warnings found"
  fi

  return "${status}"
}

copy_component() {
  local name="$1"
  local src="$2"
  local dest="$3"
  local abs_src="${REPO_DIR}/${src}"
  local abs_dest
  local abs_parent

  abs_dest="$(resolve_dest_path "${dest}")"
  abs_parent="$(dirname "${abs_dest}")"
  mkdir -p "${abs_parent}"

  if (( DRY_RUN )); then
    log "DRY-RUN copy ${abs_src} -> ${abs_dest}"
    return
  fi

  if [[ -d "${abs_src}" ]]; then
    mkdir -p "${abs_dest}"
    cp -a "${abs_src}/." "${abs_dest}/"
  else
    cp -a "${abs_src}" "${abs_dest}"
  fi
}

install_packages_if_needed() {
  [[ "${PACKAGE_MODE}" != "never" ]] || return 0
  [[ "${#ACTIVE_PACKAGE_GROUP_ROWS[@]}" -gt 0 || "${#EXTRA_PACKAGES[@]}" -gt 0 ]] || return 0

  detect_package_manager
  if [[ "${PACKAGE_MANAGER}" == "unknown" ]]; then
    warn "package manager not detected; skip automatic package install"
    return 0
  fi

  local packages=()
  local row name tier selector package_list desc pkg
  for row in "${ACTIVE_PACKAGE_GROUP_ROWS[@]}"; do
    IFS='|' read -r name tier selector package_list desc <<< "${row}"
    read -r -a parsed <<< "${package_list}"
    for pkg in "${parsed[@]}"; do
      contains "${pkg}" "${packages[@]}" || packages+=("${pkg}")
    done
  done

  for pkg in "${EXTRA_PACKAGES[@]}"; do
    contains "${pkg}" "${packages[@]}" || packages+=("${pkg}")
  done

  [[ "${#packages[@]}" -gt 0 ]] || return 0
  local cmd
  cmd="$(package_install_cmd "${packages[@]}")" || {
    warn "no install command template for ${PACKAGE_MANAGER}"
    return 0
  }

  log
  log "Package install command:"
  log "  ${cmd}"

  if (( DRY_RUN )); then
    return 0
  fi

  if [[ "${PACKAGE_MODE}" == "auto" && "${ASSUME_YES}" -ne 1 ]]; then
    read -r -p "Run package installation? [y/N] " answer
    [[ "${answer}" =~ ^[Yy]$ ]] || return 0
  fi

  eval "${cmd}"
}

run_install() {
  local row name src dest mode desc
  install_packages_if_needed
  print_probe_summary

  if [[ "${#ACTIVE_PACKAGE_GROUP_ROWS[@]}" -gt 0 ]]; then
    log
    log "Active package groups:"
    local package_row package_name package_tier package_selector package_list package_desc
    for package_row in "${ACTIVE_PACKAGE_GROUP_ROWS[@]}"; do
      IFS='|' read -r package_name package_tier package_selector package_list package_desc <<< "${package_row}"
      log "  ${package_name} [${package_tier}; ${package_selector}]"
    done
  fi

  log
  log "Copy plan:"
  for row in "${ACTIVE_COMPONENT_ROWS[@]}"; do
    IFS='|' read -r name src dest mode desc <<< "${row}"
    log "  ${name}: ${src} -> ${dest}"
  done

  if (( DRY_RUN == 0 && ASSUME_YES == 0 )); then
    read -r -p "Proceed with copy? [y/N] " answer
    [[ "${answer}" =~ ^[Yy]$ ]] || die "Aborted"
  fi

  for row in "${ACTIVE_COMPONENT_ROWS[@]}"; do
    IFS='|' read -r name src dest mode desc <<< "${row}"
    copy_component "${name}" "${src}" "${dest}"
  done

  if (( DRY_RUN )); then
    log
    log "DRY-RUN UI profile: ${ACTIVE_UI_DENSITY}"
  else
    apply_ui_profile "${TARGET_HOME}"
  fi

  print_post_install_steps
}

list_manifest() {
  local row name src dest mode desc
  log "Components:"
  for row in "${DOTBOOTSTRAP_COMPONENTS[@]}"; do
    IFS='|' read -r name src dest mode desc <<< "${row}"
    log "  ${name} [${mode}] ${src} -> ${dest} :: ${desc}"
  done
  log
  log "Package groups:"
  for row in "${DOTBOOTSTRAP_PACKAGE_GROUPS[@]:-}"; do
    IFS='|' read -r name tier selector packages desc <<< "${row}"
    log "  ${name} [${tier}; ${selector}] :: ${packages} :: ${desc}"
  done
  log
  log "Package presets:"
  for row in "${DOTBOOTSTRAP_PACKAGE_PRESETS[@]:-}"; do
    IFS='|' read -r name items desc <<< "${row}"
    log "  ${name} :: ${items} :: ${desc}"
  done
  if [[ -v DOTBOOTSTRAP_OPTIONAL_FLOWS ]] && [[ "${#DOTBOOTSTRAP_OPTIONAL_FLOWS[@]}" -gt 0 ]]; then
    log
    log "Optional flows:"
    for row in "${DOTBOOTSTRAP_OPTIONAL_FLOWS[@]:-}"; do
      IFS='|' read -r name selector summary details <<< "${row}"
      log "  ${name} [${selector}] :: ${summary}"
      [[ -n "${details}" ]] && log "    ${details}"
    done
  fi
}

resolve_repo "${REPO_INPUT}"
load_manifest "${REPO_DIR}"
validate_manifest
detect_hardware_tags
detect_display_profile
resolve_ui_density
resolve_package_preset
collect_components
collect_packages

if (( PROBE_ONLY )); then
  print_probe_summary
  exit 0
fi

case "${ACTION}" in
  check)
    run_relevance_check
    print_probe_summary
    ;;
  install)
    run_relevance_check
    run_install
    ;;
  list)
    list_manifest
    ;;
  *)
    die "Unsupported action: ${ACTION}"
    ;;
esac
