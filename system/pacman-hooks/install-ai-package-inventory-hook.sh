#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/etc/pacman.d/hooks"
TARGET_FILE="${TARGET_DIR}/95-ai-package-inventory-stale.hook"
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${TEMPLATE_DIR}/95-ai-package-inventory-stale.hook.template"
TARGET_USER="${SUDO_USER:-${USER}}"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
  echo "Template not found: ${TEMPLATE_FILE}" >&2
  exit 1
fi

if [[ -z "${TARGET_HOME}" ]]; then
  echo "Could not resolve home for user ${TARGET_USER}" >&2
  exit 1
fi

mkdir -p "${TARGET_DIR}"

sed \
  -e "s|@USER@|${TARGET_USER}|g" \
  -e "s|@HOME@|${TARGET_HOME}|g" \
  "${TEMPLATE_FILE}" > "${TARGET_FILE}"

chmod 644 "${TARGET_FILE}"
echo "Installed ${TARGET_FILE}"
