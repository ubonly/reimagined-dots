#!/usr/bin/env bash
MODE="$1"
if [ "$MODE" != "dark" ] && [ "$MODE" != "light" ]; then
    MODE="dark"
fi

echo "$MODE" > "$HOME/.config/quickshell/theme_mode.txt"

# Rerun matugen on current wallpaper
WP_PATH_FILE="$HOME/.config/quickshell/wallpaper_path.txt"
if [ -f "$WP_PATH_FILE" ]; then
    WP=$(cat "$WP_PATH_FILE")
    if [ -n "$WP" ] && [ -f "$WP" ]; then
        matugen image "$WP" -m "$MODE" --source-color-index 0 --quiet
        matugen image "$WP" -m "$MODE" --source-color-index 0 -j hex > "$HOME/.config/quickshell/colors.json"
    fi
fi
