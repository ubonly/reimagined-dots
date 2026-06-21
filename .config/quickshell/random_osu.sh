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
CURRENT_IMG="$PICTURES_DIR/random_osu"

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
        
        if width < 1024 or height < 576:
            raise SystemExit(1)
            
        target_ratio = 16.0 / 9.0
        current_ratio = float(width) / float(height)
        
        if abs(current_ratio - target_ratio) > 0.01:
            if current_ratio > target_ratio:
                # too wide, crop sides
                new_width = int(height * target_ratio)
                offset = (width - new_width) // 2
                img = img.crop((offset, 0, offset + new_width, height))
            else:
                # too tall, crop top/bottom
                new_height = int(width / target_ratio)
                offset = (height - new_height) // 2
                img = img.crop((0, offset, width, offset + new_height))
            img.save(path)
except Exception:
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
        local link=""
        
        local UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        # Query osu! seasonal backgrounds API
        local response=$(curl -s -A "$UA" --max-time 5 "https://osu.ppy.sh/api/v2/seasonal-backgrounds")
        if [ -n "$response" ]; then
            local images=$(echo "$response" | jq '.backgrounds | length' -r 2>/dev/null || echo "0")
            if [ "$images" -gt 0 ]; then
                local randomIndex=$((RANDOM % images))
                link=$(echo "$response" | jq ".backgrounds[$randomIndex].url" -r 2>/dev/null)
            fi
        fi
        
        # Fallback to konachan if osu! API fails
        if [ -z "$link" ] || [ "$link" = "null" ]; then
            local page=$((1 + RANDOM % 300))
            local response_kc=$(curl -s -A "$UA" --max-time 5 "https://konachan.net/post.json?tags=rating%3Asafe&limit=1&page=$page")
            link=$(echo "$response_kc" | grep -o '"file_url":"[^"]*' | grep -o 'https[^"]*')
        fi

        if [ -n "$link" ] && [ "$link" != "null" ]; then
            local ext="${link##*.}"
            ext="${ext%%\?*}"
            [[ "$ext" =~ ^(jpg|png|jpeg|webp)$ ]] || ext="jpg"
            
            # Download with 3 second timeout
            curl -sL -A "$UA" --max-time 3 "$link" -o "${target}.${ext}"
            
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

PROVIDER="osu"
PREFETCH_DIR="$HOME/.cache/quickshell/prefetch"
mkdir -p "$PREFETCH_DIR"

if [ "$1" = "--fetch-only" ]; then
    fetch_image "$PREFETCH_DIR/next_${PROVIDER}"
    exit 0
fi

PREFETCHED_PATH_FILE="$PREFETCH_DIR/next_${PROVIDER}.path"
PREFETCHED_IMG=""
if [ -f "$PREFETCHED_PATH_FILE" ]; then
    PREFETCHED_IMG=$(cat "$PREFETCHED_PATH_FILE" 2>/dev/null)
fi

if [ -n "$PREFETCHED_IMG" ] && [ -f "$PREFETCHED_IMG" ]; then
    echo "Используем предзагруженные обои: $PREFETCHED_IMG"
    ext="${PREFETCHED_IMG##*.}"
    cp "$PREFETCHED_IMG" "${CURRENT_IMG}.${ext}"
    echo "${CURRENT_IMG}.${ext}" > "${CURRENT_IMG}.path"
    
    # Удаляем manifest, чтобы не использовать дважды
    rm -f "$PREFETCHED_PATH_FILE"
    
    # Мгновенно применяем обои
    bash "$HOME/.config/quickshell/set_wallpaper.sh" "${CURRENT_IMG}.${ext}"
    
    # Запускаем фоновое скачивание на следующий раз
    nohup bash "$0" --fetch-only >/dev/null 2>&1 &
    exit 0
fi

# Кэш пуст (первый запуск)
echo "Кэш пуст, скачиваем в переднем плане..."
fetch_image "$CURRENT_IMG"
if [ -f "${CURRENT_IMG}.path" ]; then
    curr_file=$(cat "${CURRENT_IMG}.path")
    bash "$HOME/.config/quickshell/set_wallpaper.sh" "$curr_file"
fi

# Запускаем фоновое скачивание на будущее
nohup bash "$0" --fetch-only >/dev/null 2>&1 &

