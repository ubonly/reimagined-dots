#!/usr/bin/env bash
set -euo pipefail

if qs ipc call lock activate >/dev/null 2>&1; then
    exit 0
fi

if hyprctl dispatch 'hl.dsp.global("quickshell:lock")' >/dev/null 2>&1; then
    exit 0
fi

if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

exec hyprlock
