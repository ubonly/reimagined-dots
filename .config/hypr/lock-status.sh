#!/usr/bin/env bash
set -euo pipefail

network="offline"
if command -v nmcli >/dev/null 2>&1; then
    state="$(nmcli -t -f STATE general status 2>/dev/null || true)"
    case "$state" in
        connected*) network="connected" ;;
        connecting*) network="connecting" ;;
    esac
fi

battery=""
for bat in /sys/class/power_supply/BAT*; do
    [ -e "$bat/capacity" ] || continue
    capacity="$(cat "$bat/capacity" 2>/dev/null || true)"
    status="$(cat "$bat/status" 2>/dev/null || true)"
    if [ -n "$capacity" ]; then
        battery="  ${capacity}%"
        [ "$status" = "Charging" ] && battery="${battery} charging"
    fi
    break
done

layout="$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[0].active_keymap // empty' 2>/dev/null || true)"
[ -n "$layout" ] && layout="  ${layout}"

printf '%s%s%s\n' "$network" "$battery" "$layout"
