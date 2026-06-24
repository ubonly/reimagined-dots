#!/usr/bin/env python3
# list-apps.py — Fast desktop entry parser for Quickshell
import os
import json
from pathlib import Path

# Icon theme search order: hicolor/native first (matches Qt behaviour), Tela as fallback
ICON_THEMES = [
    "hicolor",
    "Adwaita",
    "Papirus",
    "Tela-circle-green",
    "Tela-circle",
]

ICON_SIZES = ["scalable", "256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "22x22"]
ICON_EXTS = [".svg", ".png", ".xpm"]

ICON_DIRS = [
    "/usr/share/icons",
    os.path.expanduser("~/.local/share/icons"),
    "/usr/local/share/icons",
    "/var/lib/flatpak/exports/share/icons",
    os.path.expanduser("~/.local/share/flatpak/exports/share/icons"),
]

PIXMAP_DIRS = [
    "/usr/share/pixmaps",
    "/usr/local/share/pixmaps",
]

def find_icon_path(icon_name):
    """Resolve icon name to absolute file path."""
    if not icon_name:
        return None

    # If it's already an absolute path
    if icon_name.startswith("/") and os.path.isfile(icon_name):
        return icon_name

    # Search icon themes
    for theme in ICON_THEMES:
        for base in ICON_DIRS:
            theme_dir = os.path.join(base, theme)
            if not os.path.isdir(theme_dir):
                continue
            for size in ICON_SIZES:
                for category in ["apps", "actions", "devices", "places", "status", "mimetypes"]:
                    for ext in ICON_EXTS:
                        path = os.path.join(theme_dir, size, category, icon_name + ext)
                        if os.path.isfile(path):
                            return path

    # Fallback: search all icon dirs without theme
    for base in ICON_DIRS:
        for root, dirs, files in os.walk(base):
            for ext in ICON_EXTS:
                candidate = icon_name + ext
                if candidate in files:
                    return os.path.join(root, candidate)

    # Fallback: pixmaps
    for base in PIXMAP_DIRS:
        for ext in ICON_EXTS:
            path = os.path.join(base, icon_name + ext)
            if os.path.isfile(path):
                return path

    return None


def parse_desktop_file(filepath):
    app = {}
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            in_desktop_entry = False
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if line.startswith('['):
                    if line == '[Desktop Entry]':
                        in_desktop_entry = True
                    else:
                        in_desktop_entry = False
                    continue

                if not in_desktop_entry:
                    continue

                if '=' not in line:
                    continue

                key, val = line.split('=', 1)
                key = key.strip()
                val = val.strip()

                if key == 'Type':
                    if val != 'Application':
                        return None
                elif key == 'NoDisplay' and val.lower() == 'true':
                    return None
                elif key == 'Hidden' and val.lower() == 'true':
                    return None
                elif key == 'Name' and 'name' not in app:
                    app['name'] = val
                elif key == 'GenericName' and 'genericName' not in app:
                    app['genericName'] = val
                elif key == 'Comment' and 'comment' not in app:
                    app['comment'] = val
                elif key == 'Keywords' and 'keywords' not in app:
                    app['keywords'] = val.replace(';', ' ')
                elif key == 'Categories' and 'categories' not in app:
                    app['categories'] = val.replace(';', ' ')
                elif key == 'Icon' and 'icon' not in app:
                    app['icon'] = val
                elif key == 'Exec' and 'exec' not in app:
                    for arg in ['%u', '%U', '%f', '%F', '%d', '%D', '%n', '%N', '%i', '%c', '%k', '%v', '%m']:
                        val = val.replace(arg, '')
                    app['exec'] = val.strip()

        if 'name' in app and 'exec' in app:
            icon_name = app.get('icon', 'application-x-executable')
            resolved = find_icon_path(icon_name)
            if resolved:
                app['iconPath'] = resolved
            else:
                app['iconPath'] = ''
            app['icon'] = icon_name
            app['desktopId'] = os.path.basename(filepath)
            return app
    except Exception:
        pass
    return None


def main():
    home = str(Path.home())
    dirs = [
        "/usr/share/applications",
        os.path.join(home, ".local/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        os.path.join(home, ".local/share/flatpak/exports/share/applications"),
        "/var/lib/snapd/desktop/applications",
        "/usr/local/share/applications"
    ]

    apps = []
    seen_execs = set()

    for d in dirs:
        if not os.path.exists(d):
            continue
        for entry in os.scandir(d):
            if entry.is_file() and entry.name.endswith('.desktop'):
                app = parse_desktop_file(entry.path)
                if app:
                    dedup_key = f"{app['name']}:{app['exec']}"
                    if dedup_key not in seen_execs:
                        seen_execs.add(dedup_key)
                        apps.append(app)

    print(json.dumps(apps))


if __name__ == "__main__":
    main()
