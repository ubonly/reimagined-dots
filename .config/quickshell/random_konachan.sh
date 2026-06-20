#!/usr/bin/env bash

# Kill any other running instances of this script
for pid in $(pgrep -f "$(basename "$0")"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

PICTURES_DIR="$HOME/Pictures/Wallpapers"
mkdir -p "$PICTURES_DIR"
CONFIG_FILE="$HOME/.config/quickshell/config.json"
UPSCALE_CACHE_DIR="$HOME/.cache/quickshell/wallpaper-upscale"
CURRENT_IMG="$PICTURES_DIR/random_konachan"

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

maybe_upscale_wallpaper() {
    local input="$1"
    local enabled
    local factor
    local upscaler=""

    enabled=$(read_config_val "wallpaperUpscaleEnabled" "false" | tr '[:upper:]' '[:lower:]')
    factor=$(read_config_val "wallpaperUpscaleFactor" "2")

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

validate_wallpaper() {
    python3 - "$1" <<'PY'
from PIL import Image
import sys

path = sys.argv[1]
try:
    with Image.open(path) as img:
        width, height = img.size
except Exception:
    raise SystemExit(1)

if width < 1920 or height < 1080:
    raise SystemExit(1)

if width * 9 != height * 16:
    raise SystemExit(1)
PY
}

generate_colors() {
    local image="$1"
    local mode="$2"

    matugen image "$image" -m "$mode" --source-color-index 0 --quiet
    matugen image "$image" -m "$mode" --source-color-index 0 -j hex > "$HOME/.config/quickshell/colors.json"
}

fetch_image() {
    local target="$1"
    
    while true; do
        # Use wallhaven for much higher quality natively (at least 1920x1080)
        local response=$(curl -s --max-time 5 "https://wallhaven.cc/api/v1/search?categories=010&purity=100&sorting=random&atleast=1920x1080&ratios=16x9&seed=$RANDOM")
        
        local link=""
        if command -v jq &>/dev/null; then
            link=$(echo "$response" | jq '.data[0].path' -r 2>/dev/null)
        fi

        # Fallback to konachan if wallhaven fails
        if [ -z "$link" ] || [ "$link" = "null" ]; then
            local page=$((1 + RANDOM % 500))
            response=$(curl -s --max-time 5 "https://konachan.net/post.json?tags=rating%3Asafe+width%3A1920+height%3A1080&limit=1&page=$page")
            link=$(echo "$response" | grep -o '"file_url":"[^"]*' | grep -o 'https[^"]*')
        fi

        if [ -n "$link" ] && [ "$link" != "null" ]; then
            local ext="${link##*.}"
            ext="${ext%%\?*}"
            [[ "$ext" =~ ^(jpg|png|jpeg|webp)$ ]] || ext="jpg"
            
            # Download with 3 second timeout
            curl -sL --max-time 3 "$link" -o "${target}.${ext}"
            
            if [ $? -eq 0 ] && [ -s "${target}.${ext}" ]; then
                if ! validate_wallpaper "${target}.${ext}"; then
                    rm -f "${target}.${ext}"
                    continue
                fi

                final_wallpaper=$(maybe_upscale_wallpaper "${target}.${ext}")

                # Save a copy to the archive folder
                ARCHIVE_DIR="$HOME/Pictures/Saved_Wallpapers"
                mkdir -p "$ARCHIVE_DIR"
                cp "${target}.${ext}" "$ARCHIVE_DIR/wallpaper_$(date +%Y%m%d_%H%M%S).${ext}"
                
                echo "$final_wallpaper" > "${target}.path"
                break
            fi
        fi
    done
}

fetch_image "$CURRENT_IMG"
if [ -f "${CURRENT_IMG}.path" ]; then
    curr_file=$(cat "${CURRENT_IMG}.path")
    # Delegate wallpaper application to set_wallpaper.sh
    bash "$HOME/.config/quickshell/set_wallpaper.sh" "$curr_file"
fi

