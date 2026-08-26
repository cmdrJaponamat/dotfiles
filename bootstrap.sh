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
  --extra-packages "pkg1 pkg2"
  --packages auto|always|never
  --dry-run
  --yes
  --help

Examples:
  ./bootstrap.sh --action check
  ./bootstrap.sh --action install --dry-run
  ./bootstrap.sh --repo https://example.com/dotfiles.git --action check
  ./bootstrap.sh --component niri --component rofi --package-group optional-gui
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
SELECTED_COMPONENTS=()
SKIPPED_COMPONENTS=()
SELECTED_PACKAGE_GROUPS=()
SKIPPED_PACKAGE_GROUPS=()

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
    --extra-packages)
      read -r -a extra <<< "${2:?missing extra packages}"
      EXTRA_PACKAGES+=("${extra[@]}")
      shift 2
      ;;
    --packages)
      PACKAGE_MODE="${2:?missing package mode}"
      shift 2
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
  local row name packages desc
  for row in "${DOTBOOTSTRAP_PACKAGE_GROUPS[@]:-}"; do
    IFS='|' read -r name packages desc <<< "${row}"
    [[ -n "${name}" && -n "${packages}" ]] || die "Bad package group row: ${row}"

    if contains "${name}" "${SKIPPED_PACKAGE_GROUPS[@]}"; then
      continue
    fi

    if [[ "${#SELECTED_PACKAGE_GROUPS[@]}" -gt 0 ]]; then
      contains "${name}" "${SELECTED_PACKAGE_GROUPS[@]}" || continue
    else
      if contains "${name}" "${DOTBOOTSTRAP_DEFAULT_PACKAGE_GROUPS[@]:-}"; then
        :
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
  log
  log "Component validation:"
  for row in "${ACTIVE_COMPONENT_ROWS[@]}"; do
    IFS='|' read -r name src dest mode desc <<< "${row}"
    abs_src="${REPO_DIR}/${src}"
    abs_dest="${TARGET_HOME}/${dest}"
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
    if rg -n --fixed-strings "${pattern}" "${REPO_DIR}" -g '!**/.git/**' >/tmp/dotbootstrap_warn.$$ 2>/dev/null; then
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
  local abs_dest="${TARGET_HOME}/${dest}"
  local abs_parent

  abs_parent="$(dirname "${abs_dest}")"
  mkdir -p "${abs_parent}"

  if (( DRY_RUN )); then
    log "DRY-RUN copy ${abs_src} -> ${abs_dest}"
    return
  fi

  rm -rf "${abs_dest}"
  cp -a "${abs_src}" "${abs_dest}"
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
  local row name package_list desc pkg
  for row in "${ACTIVE_PACKAGE_GROUP_ROWS[@]}"; do
    IFS='|' read -r name package_list desc <<< "${row}"
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
    IFS='|' read -r name packages desc <<< "${row}"
    log "  ${name} :: ${packages} :: ${desc}"
  done
}

resolve_repo "${REPO_INPUT}"
load_manifest "${REPO_DIR}"
validate_manifest
collect_components
collect_packages

case "${ACTION}" in
  check)
    run_relevance_check
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
