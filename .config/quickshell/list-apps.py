#!/usr/bin/env python3
"""List installed desktop applications for the QuickShell launcher."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Iterable


BASE_DIR = Path(__file__).resolve().parent
APPS_CACHE = BASE_DIR / "apps.json"

APP_DIRS = [
    Path("/usr/share/applications"),
    Path.home() / ".local/share/applications",
    Path("/var/lib/flatpak/exports/share/applications"),
    Path.home() / ".local/share/flatpak/exports/share/applications",
    Path("/var/lib/snapd/desktop/applications"),
    Path("/usr/local/share/applications"),
]

ICON_THEMES = [
    "hicolor",
    "Adwaita",
    "Papirus",
    "Tela-circle-green",
    "Tela-circle",
]

ICON_DIRS = [
    Path("/usr/share/icons"),
    Path.home() / ".local/share/icons",
    Path("/usr/local/share/icons"),
    Path("/var/lib/flatpak/exports/share/icons"),
    Path.home() / ".local/share/flatpak/exports/share/icons",
]

PIXMAP_DIRS = [
    Path("/usr/share/pixmaps"),
    Path("/usr/local/share/pixmaps"),
]

ICON_SIZES = ["scalable", "256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "22x22"]
ICON_CATEGORIES = ["apps", "actions", "devices", "places", "status", "mimetypes"]
ICON_EXTENSIONS = [".svg", ".png", ".xpm"]
EXEC_FIELD_CODES = ["%u", "%U", "%f", "%F", "%d", "%D", "%n", "%N", "%i", "%c", "%k", "%v", "%m"]

_icon_index: dict[str, str] | None = None


def iter_desktop_files() -> Iterable[Path]:
    for app_dir in APP_DIRS:
        if not app_dir.is_dir():
            continue
        try:
            entries = sorted(app_dir.iterdir(), key=lambda path: path.name)
        except OSError:
            continue

        for entry in entries:
            if entry.is_file() and entry.suffix == ".desktop":
                yield entry


def desktop_generation() -> str:
    items = []
    for path in iter_desktop_files():
        try:
            stat = path.stat()
            items.append(f"{path}:{stat.st_mtime_ns}:{stat.st_size}")
        except OSError:
            items.append(f"{path}:missing")
    return "|".join(items)


def clean_exec(value: str) -> str:
    for field_code in EXEC_FIELD_CODES:
        value = value.replace(field_code, "")
    return value.strip()


def read_desktop_entry(path: Path) -> dict[str, str] | None:
    app: dict[str, str] = {}
    in_desktop_entry = False

    try:
        with path.open("r", encoding="utf-8") as file:
            for raw_line in file:
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue

                if line.startswith("["):
                    in_desktop_entry = line == "[Desktop Entry]"
                    continue

                if not in_desktop_entry or "=" not in line:
                    continue

                key, value = [part.strip() for part in line.split("=", 1)]

                if key == "Type" and value != "Application":
                    return None
                if key in {"NoDisplay", "Hidden"} and value.lower() == "true":
                    return None

                read_desktop_field(app, key, value)
    except OSError:
        return None

    if "name" not in app or "exec" not in app:
        return None

    icon_name = app.get("icon", "application-x-executable")
    app["icon"] = icon_name
    app["iconPath"] = find_icon_path(icon_name) or ""
    app["desktopId"] = path.name
    return app


def read_desktop_field(app: dict[str, str], key: str, value: str) -> None:
    if key == "Name" and "name" not in app:
        app["name"] = value
    elif key == "GenericName" and "genericName" not in app:
        app["genericName"] = value
    elif key == "Comment" and "comment" not in app:
        app["comment"] = value
    elif key == "Keywords" and "keywords" not in app:
        app["keywords"] = value.replace(";", " ")
    elif key == "Categories" and "categories" not in app:
        app["categories"] = value.replace(";", " ")
    elif key == "Icon" and "icon" not in app:
        app["icon"] = value
    elif key == "Exec" and "exec" not in app:
        app["exec"] = clean_exec(value)


def find_icon_path(icon_name: str) -> str | None:
    if not icon_name:
        return None

    icon_path = Path(icon_name).expanduser()
    if icon_path.is_absolute() and icon_path.is_file():
        return str(icon_path)

    direct = find_icon_in_known_locations(icon_name)
    if direct:
        return direct

    return icon_index().get(icon_name)


def find_icon_in_known_locations(icon_name: str) -> str | None:
    for theme in ICON_THEMES:
        for base_dir in ICON_DIRS:
            theme_dir = base_dir / theme
            if not theme_dir.is_dir():
                continue

            for size in ICON_SIZES:
                for category in ICON_CATEGORIES:
                    for extension in ICON_EXTENSIONS:
                        path = theme_dir / size / category / f"{icon_name}{extension}"
                        if path.is_file():
                            return str(path)

    for base_dir in PIXMAP_DIRS:
        for extension in ICON_EXTENSIONS:
            path = base_dir / f"{icon_name}{extension}"
            if path.is_file():
                return str(path)

    return None


def icon_index() -> dict[str, str]:
    global _icon_index

    if _icon_index is not None:
        return _icon_index

    index: dict[str, str] = {}
    for base_dir in ICON_DIRS:
        if not base_dir.is_dir():
            continue

        for root, _, files in os.walk(base_dir):
            for filename in files:
                stem, extension = os.path.splitext(filename)
                if extension in ICON_EXTENSIONS and stem not in index:
                    index[stem] = str(Path(root) / filename)

    _icon_index = index
    return index


def list_apps() -> list[dict[str, str]]:
    apps = []
    seen = set()

    for desktop_file in iter_desktop_files():
        app = read_desktop_entry(desktop_file)
        if not app:
            continue

        dedup_key = (app["name"], app["exec"])
        if dedup_key in seen:
            continue

        seen.add(dedup_key)
        apps.append(app)

    return apps


def write_apps_cache(payload: str) -> None:
    try:
        APPS_CACHE.write_text(payload, encoding="utf-8")
    except OSError:
        pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="List launcher applications.")
    parser.add_argument(
        "--fingerprint",
        action="store_true",
        help="print a generation string for installed desktop entries",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.fingerprint:
        print(desktop_generation())
        return

    payload = json.dumps(list_apps(), ensure_ascii=False)
    write_apps_cache(payload)
    print(payload)


if __name__ == "__main__":
    main()
