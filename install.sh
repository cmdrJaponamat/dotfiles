#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

exec "${REPO_DIR}/bootstrap.sh" --action install --repo "${REPO_DIR}" "$@"
