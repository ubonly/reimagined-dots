#!/usr/bin/env bash

WP="$1"
WP_PATH_FILE="$HOME/.config/quickshell/wallpaper_path.txt"
WP_STATE_FILE="$HOME/.config/quickshell/wallpaper_state.txt"
UPSCALE_ENABLED_FILE="$HOME/.config/quickshell/wallpaper_upscale_enabled.txt"
UPSCALE_FACTOR_FILE="$HOME/.config/quickshell/wallpaper_upscale_factor.txt"
UPSCALE_CACHE_DIR="$HOME/.cache/quickshell/wallpaper-upscale"

write_file() {
    local file="$1"
    local content="$2"
    local tmp="${file}.tmp.$$"
    printf '%s\n' "$content" > "$tmp" && mv "$tmp" "$file"
}

read_setting() {
    local file="$1"
    local fallback="$2"
    if [ -f "$file" ]; then
        cat "$file" 2>/dev/null | head -n1
    else
        printf '%s\n' "$fallback"
    fi
}

maybe_upscale_wallpaper() {
    local input="$1"
    local enabled
    local factor
    local upscaler=""

    enabled=$(read_setting "$UPSCALE_ENABLED_FILE" "false" | tr '[:upper:]' '[:lower:]')
    factor=$(read_setting "$UPSCALE_FACTOR_FILE" "2")

    if [ "$enabled" != "true" ] || { [ "$factor" != "2" ] && [ "$factor" != "4" ]; }; then
        printf '%s\n' "$input"
        return 0
    fi

    if command -v upscayl-ncnn >/dev/null 2>&1; then
        upscaler="upscayl-ncnn"
    elif command -v realesrgan-ncnn-vulkan >/dev/null 2>&1; then
        upscaler="realesrgan-ncnn-vulkan"
    fi

    if [ -z "$upscaler" ]; then
        printf '%s\n' "$input"
        return 0
    fi

    mkdir -p "$UPSCALE_CACHE_DIR"

    local base
    local output
    base="$(basename "${input%.*}")"
    output="$(mktemp "$UPSCALE_CACHE_DIR/${base}-x${factor}.XXXXXX.png")" || {
        printf '%s\n' "$input"
        return 0
    }

    if "$upscaler" -i "$input" -o "$output" -s "$factor" -n realesrgan-x4plus-anime -f png >/dev/null 2>&1 && [ -s "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    rm -f "$output"
    printf '%s\n' "$input"
}

if [ -z "$WP" ]; then
    # If no wallpaper provided, try to open a file picker
    if command -v zenity &>/dev/null; then
        WP="$(zenity --file-selection --title="Choose wallpaper" --file-filter="Images | *.png *.jpg *.jpeg *.webp *.avif *.bmp")"
    fi
fi

if [ -z "$WP" ] || [ ! -f "$WP" ]; then
    exit 1
fi

FINAL_WP="$(maybe_upscale_wallpaper "$WP")"

# Save the path
write_file "$WP_PATH_FILE" "$FINAL_WP"
write_file "$WP_STATE_FILE" "$(date +%s%N)|$FINAL_WP"

# Set wallpaper via hyprpaper
hyprctl hyprpaper unload all
hyprctl hyprpaper preload "$FINAL_WP"
for mon in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl hyprpaper wallpaper "$mon,$FINAL_WP"
done

# Reload quickshell background if any? Quickshell BackgroundWindow.qml might be using wallpaper_path.txt!
# Wait, let's see how Quickshell background is updated. It might be reading colors.json

# Run matugen
MODE=$(cat "$HOME/.config/quickshell/theme_mode.txt" 2>/dev/null || echo "dark")
if [ "$MODE" != "dark" ] && [ "$MODE" != "light" ]; then
    MODE="dark"
fi

matugen image "$FINAL_WP" -m "$MODE" --source-color-index 0 --quiet
matugen image "$FINAL_WP" -m "$MODE" --source-color-index 0 -j hex > "$HOME/.config/quickshell/colors.json"
