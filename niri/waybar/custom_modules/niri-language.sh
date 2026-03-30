#!/usr/bin/env bash

set -eu

ensure_niri_socket() {
    if [ -n "${NIRI_SOCKET:-}" ]; then
        return 0
    fi

    pid="$(pgrep -u "$USER" -x niri | head -n 1 || true)"
    if [ -z "$pid" ] || [ ! -r "/proc/$pid/environ" ]; then
        return 1
    fi

    NIRI_SOCKET="$(
        tr '\0' '\n' < "/proc/$pid/environ" | awk -F= '/^NIRI_SOCKET=/ {sub(/^NIRI_SOCKET=/, "", $0); print; exit}'
    )"
    export NIRI_SOCKET
    [ -n "$NIRI_SOCKET" ]
}

if ! ensure_niri_socket; then
    printf '{"text":"   ??","tooltip":"Keyboard layout: NIRI_SOCKET unavailable"}\n'
    exit 0
fi

current_layout="$(
    niri msg -j keyboard-layouts 2>/dev/null | python -c '
import json, sys
payload = sys.stdin.read().strip()
if not payload:
    print("")
    raise SystemExit(0)
data = json.loads(payload)
names = data.get("names") or []
idx = data.get("current_idx")
print(names[idx] if isinstance(idx, int) and 0 <= idx < len(names) else "")
'
)"

case "$current_layout" in
    "English (US)")
        text="En"
        ;;
    "Russian")
        text="Ru"
        ;;
    "")
        text="??"
        current_layout="Layout unavailable"
        ;;
    *)
        text="$(printf '%s' "$current_layout" | cut -c1-2)"
        ;;
esac

printf '{"text":"   %s","tooltip":"Keyboard layout: %s"}\n' "$text" "$current_layout"
