#!/usr/bin/env bash

get_pictures_dir() {
    if command -v xdg-user-dir &> /dev/null; then
        xdg-user-dir PICTURES
        return
    fi

    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
    if [ -f "$config_file" ]; then
        local pictures_path
        pictures_path=$(source "$config_file" >/dev/null 2>&1; echo "$XDG_PICTURES_DIR")
        echo "${pictures_path/#\$HOME/$HOME}"
        return
    fi

    echo "$HOME/Pictures"
}

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PICTURES_DIR=$(get_pictures_dir)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PICTURES_DIR/Wallpapers"
page=$((1 + RANDOM % 1000))
quickshellConfigPath="$XDG_CONFIG_HOME/quickshell/config.json"

userAgent=$(jq -r '.networking.userAgent // empty' "$quickshellConfigPath" 2>/dev/null)
if [ -z "$userAgent" ]; then
    userAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
fi

tags=$(jq -r '.konachanTags // empty' "$quickshellConfigPath" 2>/dev/null)
if [ -z "$tags" ]; then
    tags_encoded="rating%3Asafe"
else
    if [[ ! "$tags" =~ rating: ]]; then
        tags="rating:safe $tags"
    fi
    tags_encoded=$(jq -rn --arg tags "$tags" '$tags | @uri')
fi

response=$(curl -s -A "$userAgent" "https://konachan.net/post.json?tags=${tags_encoded}&limit=1&page=$page")
link=$(echo "$response" | jq '.[0].file_url' -r)

if [ -z "$link" ] || [ "$link" = "null" ]; then
    # Fallback to no tags safe search if custom tags returned empty result
    response=$(curl -s -A "$userAgent" "https://konachan.net/post.json?tags=rating%3Asafe&limit=1&page=$page")
    link=$(echo "$response" | jq '.[0].file_url' -r)
fi

if [ -n "$link" ] && [ "$link" != "null" ]; then
    ext=$(echo "$link" | awk -F. '{print $NF}')
    downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper.$ext"
    currentWallpaperPath=$(jq -r '.wallpaperPath // empty' "$quickshellConfigPath" 2>/dev/null)
    
    if [ "$downloadPath" == "$currentWallpaperPath" ]; then
        downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper-1.$ext"
    fi
    
    curl -s -A "$userAgent" "$link" -o "$downloadPath"
    "$SCRIPT_DIR/set_wallpaper.sh" "$downloadPath"
fi
