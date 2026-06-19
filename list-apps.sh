#!/bin/bash
# list-apps.sh — export JSON of installed apps
# in format of: [{"name":"...", "icon":"...", "exec":"..."},...]

dirs="/usr/share/applications $HOME/.local/share/applications"
echo "["
first=true

for dir in $dirs; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.desktop; do
        [ -f "$f" ] || continue

        # Пропускаем NoDisplay=true
        grep -qi "^NoDisplay=true" "$f" 2>/dev/null && continue
        # Только Type=Application
        grep -qi "^Type=Application" "$f" 2>/dev/null || continue

        name=$(grep -m1 "^Name=" "$f" | cut -d= -f2-)
        icon=$(grep -m1 "^Icon=" "$f" | cut -d= -f2-)
        exec_raw=$(grep -m1 "^Exec=" "$f" | cut -d= -f2-)
        # Убираем %u %U %f %F и т.д.
        exec_cmd=$(echo "$exec_raw" | sed 's/ %[uUfFdDnNickvm]//g')

        [ -z "$name" ] && continue
        [ -z "$exec_cmd" ] && continue
        [ -z "$icon" ] && icon="application-x-executable"

        # JSON escape
        name=$(echo "$name" | sed 's/"/\\"/g')
        exec_cmd=$(echo "$exec_cmd" | sed 's/"/\\"/g')
        icon=$(echo "$icon" | sed 's/"/\\"/g')

        $first || echo ","
        first=false
        printf '{"name":"%s","icon":"%s","exec":"%s"}' "$name" "$icon" "$exec_cmd"
    done
done

echo "]"
