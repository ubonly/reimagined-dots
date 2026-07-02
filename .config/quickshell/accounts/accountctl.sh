#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/accountctl"

if [ -x "$HELPER" ]; then
    exec "$HELPER" "$@"
fi

if command -v reimagined-accountctl >/dev/null 2>&1; then
    exec reimagined-accountctl "$@"
fi

printf '%s\n' '{"provider":"google","status":"not_connected","displayName":"","email":"","avatar":"","message":"Account helper is not built.","error":"","configured":false,"loggedIn":false,"busy":false}'
