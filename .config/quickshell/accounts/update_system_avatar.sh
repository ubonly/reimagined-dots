#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
AVATAR_PATH="${2:-}"

FACE_FILE="$HOME/.face"
FACE_ICON_FILE="$HOME/.face.icon"

BACKUP_FACE="$HOME/.face.backup"
BACKUP_FACE_ICON="$HOME/.face.icon.backup"

if [ "$ACTION" = "apply" ]; then
    if [ -n "$AVATAR_PATH" ] && [ -f "$AVATAR_PATH" ]; then
        # Back up existing files if we haven't already and they are not our Google avatar
        if [ -f "$FACE_FILE" ] && [ ! -f "$BACKUP_FACE" ]; then
            cp "$FACE_FILE" "$BACKUP_FACE"
        fi
        if [ -f "$FACE_ICON_FILE" ] && [ ! -f "$BACKUP_FACE_ICON" ]; then
            cp "$FACE_ICON_FILE" "$BACKUP_FACE_ICON"
        fi
        
        # Copy the Google avatar
        cp "$AVATAR_PATH" "$FACE_FILE"
        cp "$AVATAR_PATH" "$FACE_ICON_FILE"
        
        echo "Google avatar applied to system avatar."
    fi
elif [ "$ACTION" = "restore" ]; then
    # Remove files if they were copied from Google avatar (or just restore backups)
    if [ -f "$BACKUP_FACE" ]; then
        mv "$BACKUP_FACE" "$FACE_FILE"
    else
        rm -f "$FACE_FILE"
    fi
    
    if [ -f "$BACKUP_FACE_ICON" ]; then
        mv "$BACKUP_FACE_ICON" "$FACE_ICON_FILE"
    else
        rm -f "$FACE_ICON_FILE"
    fi
    
    echo "System avatar restored."
fi
