#!/usr/bin/env bash
MODE="$1"
if [ "$MODE" != "dark" ] && [ "$MODE" != "light" ]; then
    MODE="dark"
fi

CONFIG_FILE="$HOME/.config/quickshell/config.json"

read_config_val() {
    local key="$1"
    local fallback="$2"
    if [ -f "$CONFIG_FILE" ]; then
        local val
        val=$(jq -r ".${key}" "$CONFIG_FILE" 2>/dev/null)
        if [ "$val" != "null" ] && [ -n "$val" ]; then
            printf '%s\n' "$val"
            return 0
        fi
    fi
    printf '%s\n' "$fallback"
}

write_config_val() {
    local key="$1"
    local value="$2"
    local tmp="${CONFIG_FILE}.tmp.$$"
    if [ ! -f "$CONFIG_FILE" ]; then
        printf '{\n  "%s": %s\n}\n' "$key" "$value" > "$CONFIG_FILE"
    else
        jq ".${key} = ${value}" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
    fi
}

# Save theme mode to JSON config
write_config_val "themeMode" "\"$MODE\""

# Rerun matugen on current wallpaper
WP=$(read_config_val "wallpaperPath" "")
if [ -n "$WP" ] && [ -f "$WP" ]; then
    matugen image "$WP" -m "$MODE" --source-color-index 0 --quiet
    matugen image "$WP" -m "$MODE" --source-color-index 0 -j hex > "$HOME/.config/quickshell/colors.json"
fi
