#!/usr/bin/env python3
import os
import hashlib
import subprocess
import sys


ICON_THEMES = [
    "hicolor",
    "Adwaita",
    "Papirus",
    "Tela-circle-green",
    "Tela-circle",
]

ICON_SIZES = [
    "scalable",
    "512x512",
    "256x256",
    "128x128",
    "64x64",
    "48x48",
    "32x32",
    "24x24",
    "22x22",
    "16x16",
]

ICON_EXTS = [".png", ".svg", ".xpm"]

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

APP_DIRS = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
    "/var/lib/snapd/desktop/applications",
    "/usr/local/share/applications",
]

ALIASES = {
    "code": ["vscode", "code", "code-oss"],
    "code-oss": ["vscode", "code-oss", "code"],
    "codium": ["vscodium", "codium", "code"],
    "vscodium": ["vscodium", "codium", "code"],
    "navigator": ["firefox"],
    "zen": ["zen-browser"],
    "spotify": ["com.spotify.Client"],
    "easyeffects": ["com.github.wwmm.easyeffects"],
    "org.kde.easyeffects": ["com.github.wwmm.easyeffects"],
    "antigravity": ["applications-development", "development", "antigravity"],
    "antigravity-ide": ["applications-development", "development", "antigravity"],
    "development": ["applications-development"],
}

KNOWN_ICON_PATHS = {
    "code": ["/usr/share/pixmaps/vscode.png", "/opt/vscodium-bin/resources/app/resources/linux/code.png"],
    "code-oss": ["/usr/share/pixmaps/vscode.png", "/opt/vscodium-bin/resources/app/resources/linux/code.png"],
    "vscode": ["/usr/share/pixmaps/vscode.png"],
    "codium": ["/opt/vscodium-bin/resources/app/resources/linux/code.png"],
    "vscodium": ["/opt/vscodium-bin/resources/app/resources/linux/code.png"],
}


def add_unique(items, value):
    if value and value not in items:
        items.append(value)


def find_icon_path(icon_name):
    if not icon_name:
        return ""

    if icon_name.startswith("/") and os.path.isfile(icon_name):
        return icon_name

    for path in KNOWN_ICON_PATHS.get(icon_name.lower(), []):
        if os.path.isfile(path):
            return path

    for base in PIXMAP_DIRS:
        for ext in ICON_EXTS:
            path = os.path.join(base, icon_name + ext)
            if os.path.isfile(path):
                return path

    for theme in ICON_THEMES:
        for base in ICON_DIRS:
            theme_dir = os.path.join(base, theme)
            if not os.path.isdir(theme_dir):
                continue
            for size in ICON_SIZES:
                for category in ["apps", "categories", "actions", "devices", "places", "status", "mimetypes"]:
                    for ext in ICON_EXTS:
                        path = os.path.join(theme_dir, size, category, icon_name + ext)
                        if os.path.isfile(path):
                            return path

    for base in ICON_DIRS:
        if not os.path.isdir(base):
            continue
        for root, _, files in os.walk(base):
            for ext in ICON_EXTS:
                candidate = icon_name + ext
                if candidate in files:
                    return os.path.join(root, candidate)

    return ""


def normalized_icon_path(path):
    if not path.lower().endswith(".svg"):
        return path

    converter = "/usr/bin/rsvg-convert"
    if not os.path.exists(converter):
        return path

    cache_dir = os.path.join("/tmp", "quickshell-icon-cache")
    os.makedirs(cache_dir, exist_ok=True)

    key = hashlib.sha1(path.encode("utf-8")).hexdigest()
    target = os.path.join(cache_dir, key + ".png")
    try:
        if os.path.exists(target) and os.path.getmtime(target) >= os.path.getmtime(path):
            return target
        subprocess.run(
            [converter, "-w", "128", "-h", "128", path, "-o", target],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if os.path.isfile(target) and os.path.getsize(target) > 0:
            return target
    except Exception:
        return path

    return path


def parse_desktop_file(path):
    fields = {"desktop_id": os.path.splitext(os.path.basename(path))[0]}
    try:
        with open(path, "r", encoding="utf-8") as f:
            in_entry = False
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("["):
                    in_entry = line == "[Desktop Entry]"
                    continue
                if not in_entry or "=" not in line:
                    continue
                key, val = line.split("=", 1)
                if key in {"Name", "Icon", "Exec", "StartupWMClass"} and key not in fields:
                    fields[key] = val.strip()
    except OSError:
        return None
    return fields if fields.get("Icon") else None


def desktop_icon_candidates(window_class):
    query = window_class.lower()
    short = query.split(".")[-1]
    matches = []

    for directory in APP_DIRS:
        if not os.path.isdir(directory):
            continue
        for entry in os.scandir(directory):
            if not entry.is_file() or not entry.name.endswith(".desktop"):
                continue
            app = parse_desktop_file(entry.path)
            if not app:
                continue

            values = {
                "desktop_id": app.get("desktop_id", "").lower(),
                "wmclass": app.get("StartupWMClass", "").lower(),
                "icon": app.get("Icon", "").lower(),
                "name": app.get("Name", "").lower(),
                "exec": os.path.basename(app.get("Exec", "").split(" ")[0]).lower(),
            }

            score = 0
            if query and query == values["wmclass"]:
                score += 100
            if query and query == values["desktop_id"]:
                score += 90
            if query and query == values["exec"]:
                score += 80
            if query and query == values["icon"]:
                score += 70
            if short and short in values.values():
                score += 45
            if query and (query in values["desktop_id"] or query in values["name"] or query in values["exec"]):
                score += 20

            if score:
                matches.append((score, app.get("Icon", "")))

    matches.sort(reverse=True)
    return [icon for _, icon in matches]


def resolve_icon_path(window_class):
    window_class = window_class.strip()
    if not window_class:
        return ""

    low = window_class.lower()
    short = low.split(".")[-1]

    icon_names = []
    for alias in ALIASES.get(low, []):
        add_unique(icon_names, alias)
    for icon in desktop_icon_candidates(window_class):
        add_unique(icon_names, icon)
    for value in [window_class, low, short, "application-x-executable"]:
        add_unique(icon_names, value)

    for icon_name in icon_names:
        path = find_icon_path(icon_name)
        if path:
            return normalized_icon_path(path)

    return ""


def main():
    window_class = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    path = resolve_icon_path(window_class)
    if path:
        print(path)
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
