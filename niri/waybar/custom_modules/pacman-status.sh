#!/usr/bin/env bash

set -eu

count_updates() {
    if command -v checkupdates >/dev/null 2>&1; then
        checkupdates 2>/dev/null | wc -l
    else
        printf '0\n'
    fi
}

print_status() {
    count="$(count_updates)"

    if [ "$count" -gt 0 ]; then
        printf '{"text":"󰚰 %s","class":"updates","tooltip":"System updates available: %s\\nLeft click: open updater"}\n' "$count" "$count"
    else
        printf '{"text":"󰚰","class":"idle","tooltip":"System is up to date\\nLeft click: open updater"}\n'
    fi
}

case "${1:-status}" in
    status)
        print_status
        ;;
    *)
        printf 'Usage: %s [status]\n' "$0" >&2
        exit 1
        ;;
esac
