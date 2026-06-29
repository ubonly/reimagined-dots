#!/usr/bin/env bash
MODE="$1"
SCHEME="$2"
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

# If a scheme was passed directly, save it immediately to avoid race condition
if [ -n "$SCHEME" ]; then
    write_config_val "matugenScheme" "\"$SCHEME\""
fi

EXTRA_FEATURES=$(read_config_val "extraFeaturesEnabled" "false")
PALETTE_TYPE=$(read_config_val "matugenScheme" "auto")
if [ "${EXTRA_FEATURES,,}" != "true" ]; then
    PALETTE_TYPE="auto"
    write_config_val "matugenScheme" "\"auto\""
fi
TYPE_ARGS=()
if [ "$PALETTE_TYPE" != "auto" ] && [ -n "$PALETTE_TYPE" ]; then
    TYPE_ARGS+=("-t" "$PALETTE_TYPE")
fi

# Rerun matugen on current wallpaper
WP=$(read_config_val "wallpaperPath" "")
if [ -n "$WP" ] && [ -f "$WP" ]; then
    matugen image "$WP" -m "$MODE" "${TYPE_ARGS[@]}" --source-color-index 0 -j hex > "$HOME/.config/quickshell/colors.json"
    python3 "$HOME/.config/quickshell/apply_matugen_pipeline.py" "$WP"
fi
