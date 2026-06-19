#!/usr/bin/env bash
bluetoothctl devices | while read -r line; do
    mac=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | awk '{$1=""; $2=""; print $0}' | sed 's/^ *//')
    info=$(bluetoothctl info "$mac")
    paired=$(echo "$info" | grep -q "Paired: yes" && echo 1 || echo 0)
    connected=$(echo "$info" | grep -q "Connected: yes" && echo 1 || echo 0)
    echo "$mac|$name|$paired|$connected"
done
