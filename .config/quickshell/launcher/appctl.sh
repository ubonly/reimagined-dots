#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/appctl"
CACHE_FILE="$SCRIPT_DIR/../apps.json"
COMMAND="${1:-list}"

if [ -x "$HELPER" ]; then
    exec "$HELPER" --cache "$CACHE_FILE" "$@"
fi

case "$COMMAND" in
    list|"")
        if [ -f "$CACHE_FILE" ]; then
            cat "$CACHE_FILE"
        else
            printf '[]\n'
        fi
        ;;
    fingerprint)
        printf '\n'
        ;;
    *)
        printf 'Unknown launcher command: %s\n' "$COMMAND" >&2
        exit 2
        ;;
esac
