#!/usr/bin/env python3
"""
Manage clipboard pins.
Usage:
  clipboard_pin.py list                    -> JSON list of pinned items (UI shape)
  clipboard_pin.py keys                    -> JSON list of pinned content keys
  clipboard_pin.py toggle <cliphist_line>  -> add or remove pin for that cliphist line
  clipboard_pin.py restore <key>           -> push pinned item back to clipboard
"""
import sys
import os
import json
import hashlib
import subprocess
import urllib.parse
from pathlib import Path

PIN_DIR = Path.home() / ".config" / "quickshell" / "clipboard_pins"
PIN_FILE = PIN_DIR / "pins.json"
PIN_IMG_DIR = PIN_DIR / "images"
PIN_DIR.mkdir(parents=True, exist_ok=True)
PIN_IMG_DIR.mkdir(parents=True, exist_ok=True)


def load_pins():
    if not PIN_FILE.exists():
        return []
    try:
        return json.loads(PIN_FILE.read_text())
    except Exception:
        return []


def save_pins(pins):
    PIN_FILE.write_text(json.dumps(pins, indent=2))


def short_hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:16]


def cmd_list():
    out = []
    for p in load_pins():
        out.append({
            "id": "pin:" + p["key"],
            "line": "pin:" + p["key"],
            "key": p["key"],
            "type": p["type"],
            "preview": p.get("preview", ""),
            "imagePath": p.get("imagePath", ""),
            "filename": p.get("filename", ""),
            "raw": p.get("raw", ""),
            "pinned": True,
        })
    print(json.dumps(out))


def cmd_keys():
    print(json.dumps([p["key"] for p in load_pins()]))


def cmd_toggle(line: str):
    parts = line.split("\t", 1)
    if len(parts) != 2:
        sys.exit(1)
    cid, data = parts
    is_image = "[[ binary data" in data
    is_file = data.startswith("file://")

    if is_image:
        img_bytes = subprocess.run(
            ["cliphist", "decode", cid], capture_output=True
        ).stdout
        if not img_bytes:
            sys.exit(1)
        key = short_hash(img_bytes)
    else:
        key = short_hash(data.encode())

    pins = load_pins()
    existing = [p for p in pins if p["key"] == key]
    if existing:
        for p in existing:
            img_file = p.get("imageFile")
            if img_file:
                try:
                    os.remove(img_file)
                except OSError:
                    pass
        pins = [p for p in pins if p["key"] != key]
        save_pins(pins)
        return

    pin = {"key": key}
    if is_image:
        pin["type"] = "image"
        img_path = PIN_IMG_DIR / f"{key}.png"
        img_path.write_bytes(img_bytes)
        pin["imageFile"] = str(img_path)
        pin["imagePath"] = f"file://{img_path}"
        pin["preview"] = "Image"
    elif is_file:
        pin["type"] = "file"
        first_uri = data.split("\n")[0].strip()
        decoded = urllib.parse.unquote(first_uri[7:])
        basename = os.path.basename(decoded)
        file_count = len([x for x in data.split("\n") if x.strip()])
        pin["filename"] = (
            f"{basename} (+{file_count-1})" if file_count > 1 else basename
        )
        pin["raw"] = data
        pin["preview"] = first_uri
    else:
        pin["type"] = "text"
        pin["raw"] = data
        preview = data.strip().replace("\n", " ")
        if len(preview) > 100:
            preview = preview[:100] + "..."
        pin["preview"] = preview

    pins.insert(0, pin)
    save_pins(pins)


def cmd_remove(key: str):
    pins = load_pins()
    for p in pins:
        if p["key"] == key:
            img_file = p.get("imageFile")
            if img_file:
                try:
                    os.remove(img_file)
                except OSError:
                    pass
    pins = [p for p in pins if p["key"] != key]
    save_pins(pins)


def cmd_restore(key: str):
    pin = next((p for p in load_pins() if p["key"] == key), None)
    if not pin:
        sys.exit(1)
    if pin["type"] == "image":
        with open(pin["imageFile"], "rb") as f:
            subprocess.run(["wl-copy", "--type", "image/png"], stdin=f)
    elif pin["type"] == "file":
        p = subprocess.Popen(
            ["wl-copy", "--type", "text/uri-list"], stdin=subprocess.PIPE
        )
        p.communicate(pin["raw"].encode())
    else:
        p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
        p.communicate(pin["raw"].encode())


def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "list":
        cmd_list()
    elif cmd == "keys":
        cmd_keys()
    elif cmd == "toggle":
        cmd_toggle(sys.argv[2])
    elif cmd == "remove":
        cmd_remove(sys.argv[2])
    elif cmd == "restore":
        cmd_restore(sys.argv[2])
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
