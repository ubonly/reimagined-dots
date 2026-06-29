#!/usr/bin/env bash
set -euo pipefail

if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

exec hyprlock
