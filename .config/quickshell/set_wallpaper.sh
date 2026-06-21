#!/usr/bin/env bash

WP="$1"
CONFIG_FILE="$HOME/.config/quickshell/config.json"
UPSCALE_CACHE_DIR="$HOME/.cache/quicksALE/wallpaper-upscale"
# Fix typo in cache dir path
UPSCALE_CACHE_DIR="$HOME/.cache/quickshell/wallpaper-upscale"
VIDEO_THUMBNAILS_DIR="$HOME/.cache/quickshell/video-thumbnails"

# Load config values in a single jq call
UPSCALE_ENABLED="false"
UPSCALE_FACTOR="2"
MATUGEN_SCHEME="scheme-tonal-spot"
THEME_MODE="dark"

if [ -f "$CONFIG_FILE" ]; then
    eval $(jq -r '
      "UPSCALE_ENABLED=" + (.wallpaperUpscaleEnabled // "false" | tostring) +
      "; UPSCALE_FACTOR=" + (.wallpaperUpscaleFactor // "2" | tostring) +
      "; MATUGEN_SCHEME=" + (.matugenScheme // "scheme-tonal-spot" | tostring) +
      "; THEME_MODE=" + (.themeMode // "dark" | tostring)
    ' "$CONFIG_FILE" 2>/dev/null)
fi

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

is_video() {
    local ext
    ext=$(printf '%s' "${1##*.}" | tr '[:upper:]' '[:lower:]')
    [[ "$ext" == "mp4" || "$ext" == "webm" || "$ext" == "mkv" || "$ext" == "avi" || "$ext" == "mov" ]]
}

maybe_upscale_wallpaper() {
    local input="$1"
    local enabled="${UPSCALE_ENABLED,,}"
    local factor="$UPSCALE_FACTOR"
    local upscaler=""

    # Don't upscale videos
    if is_video "$input"; then
        printf '%s\n' "$input"
        return 0
    fi

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
        WP="$(zenity --file-selection --title="Choose wallpaper" --file-filter="Wallpaper Files | *.png *.jpg *.jpeg *.webp *.avif *.bmp *.mp4 *.webm *.mkv *.avi *.mov")"
    fi
fi

if [ -z "$WP" ] || [ ! -f "$WP" ]; then
    exit 1
fi

FINAL_WP="$(maybe_upscale_wallpaper "$WP")"

# Save the paths in a single jq call
tmp="${CONFIG_FILE}.tmp.$$"
jq ".wallpaperPath = \"$FINAL_WP\" | .wallpaperState = \"$(date +%s%N)|$FINAL_WP\"" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"

# Get theme mode
MODE="$THEME_MODE"
if [ "$MODE" != "dark" ] && [ "$MODE" != "light" ]; then
    MODE="dark"
fi

COLOR_GEN_TARGET="$FINAL_WP"

if is_video "$FINAL_WP"; then
    if command -v mpvpaper >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1; then
        # Handle video wallpaper
        pkill -f -9 mpvpaper || true
        
        # Start mpvpaper on all monitors
        VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"
        for mon in $(hyprctl monitors -j | jq -r '.[].name'); do
            mpvpaper -o "$VIDEO_OPTS" "$mon" "$FINAL_WP" &
            sleep 0.1
        done
        
        # Generate thumbnail for matugen color scheme
        mkdir -p "$VIDEO_THUMBNAILS_DIR"
        thumbnail="$VIDEO_THUMBNAILS_DIR/$(basename "$FINAL_WP").jpg"
        if [ ! -f "$thumbnail" ]; then
            ffmpeg -y -i "$FINAL_WP" -vframes 1 "$thumbnail" >/dev/null 2>&1
        fi
        
        if [ -f "$thumbnail" ]; then
            COLOR_GEN_TARGET="$thumbnail"
        fi
    else
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Video Wallpaper Error" "Please install 'mpvpaper' and 'ffmpeg' to use video wallpapers."
        fi
        # Fall back to treat it as standard static wallpaper (will likely fail to draw, but handles gracefully)
        pkill -f -9 mpvpaper || true
    fi
else
    # Static image wallpaper: stop mpvpaper
    pkill -f -9 mpvpaper || true
    
    if command -v swww img >/dev/null 2>&1; then
        # Ensure daemon is running
        if ! swww query >/dev/null 2>&1; then
            swww-daemon &
            sleep 0.5
        fi
        
        # Calculate transition center based on cursor position
        read scale screenx screeny screensizey < <(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.scale) \(.x) \(.y) \(.height)"' 2>/dev/null)
        [ -z "$scale" ] && scale=1
        [ -z "$screenx" ] && screenx=0
        [ -z "$screeny" ] && screeny=0
        [ -z "$screensizey" ] && screensizey=1080

        cursorposx=$(hyprctl cursorpos -j | jq '.x' 2>/dev/null) || cursorposx=960
        cursorposx=$(bc <<< "scale=0; ($cursorposx - $screenx) * $scale / 1" 2>/dev/null) || cursorposx=960
        cursorposy=$(hyprctl cursorpos -j | jq '.y' 2>/dev/null) || cursorposy=540
        cursorposy=$(bc <<< "scale=0; ($cursorposy - $screeny) * $scale / 1" 2>/dev/null) || cursorposy=540
        
        swww img "$FINAL_WP" --transition-type grow --transition-pos "${cursorposx},${cursorposy}" --transition-duration 1.5 --transition-fps 60 &
    elif command -v hyprpaper >/dev/null 2>&1; then
        # Fallback to hyprpaper
        hyprctl hyprpaper unload all
        hyprctl hyprpaper preload "$FINAL_WP"
        for mon in $(hyprctl monitors -j | jq -r '.[].name'); do
            hyprctl hyprpaper wallpaper "$mon,$FINAL_WP"
        done
    fi
fi

# Run matugen color generation using COLOR_GEN_TARGET in the background
if command -v matugen >/dev/null 2>&1; then
    PALETTE_TYPE="$MATUGEN_SCHEME"
    TYPE_ARGS=()
    if [ "$PALETTE_TYPE" != "auto" ] && [ -n "$PALETTE_TYPE" ]; then
        TYPE_ARGS+=("-t" "$PALETTE_TYPE")
    fi
    (
        matugen image "$COLOR_GEN_TARGET" -m "$MODE" "${TYPE_ARGS[@]}" --source-color-index 0 --quiet
        matugen image "$COLOR_GEN_TARGET" -m "$MODE" "${TYPE_ARGS[@]}" --source-color-index 0 -j hex > "$HOME/.config/quickshell/colors.json"
        python3 "$HOME/.config/quickshell/harmonize_kitty.py"
    ) &
fi
