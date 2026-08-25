#!/usr/bin/env bash
set -euo pipefail

text="$(wl-paste --no-newline)"
[ -n "$text" ] || exit 0

sleep 0.2
wtype "$text"
