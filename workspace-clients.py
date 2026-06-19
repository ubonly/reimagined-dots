#!/usr/bin/env python3
import importlib.util
import json
import os
import subprocess
import sys


def load_resolver():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "resolve-icon.py")
    spec = importlib.util.spec_from_file_location("resolve_icon", path)
    if spec is None or spec.loader is None:
        return None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    resolver = load_resolver()
    if resolver is None:
        print("{}")
        return 1

    try:
        raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
        clients = json.loads(raw)
    except Exception:
        print("{}")
        return 1

    result = {}
    icon_cache = {}

    for client in clients:
        workspace = client.get("workspace") or {}
        ws_id = workspace.get("id", -1)
        if not isinstance(ws_id, int) or ws_id <= 0:
            continue

        key = str(ws_id)
        if key in result:
            continue

        window_class = client.get("class") or ""
        if not window_class:
            continue

        if window_class not in icon_cache:
            icon_cache[window_class] = resolver.resolve_icon_path(window_class)

        result[key] = {
            "class": window_class,
            "icon": icon_cache[window_class],
        }

    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
