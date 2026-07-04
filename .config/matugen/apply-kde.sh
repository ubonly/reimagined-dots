#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"

COLOR=$(cat ~/.config/quickshell/primary_color.txt 2>/dev/null)
MODE=$(cat ~/.config/quickshell/theme_mode.txt 2>/dev/null || echo "dark")

if [ "$MODE" == "dark" ]; then
    MODE_FLAG="-d"
else
    MODE_FLAG="-l"
fi

if [ -n "$COLOR" ]; then
    nohup kde-material-you-colors $MODE_FLAG --color "$COLOR" -sv 5 > /dev/null 2>&1 &
fi
