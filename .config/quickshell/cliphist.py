#!/usr/bin/env python3
import subprocess
import json
import os
import hashlib
import urllib.parse
from pathlib import Path

TMP_DIR = Path("/tmp/quickshell-cliphist")
TMP_DIR.mkdir(parents=True, exist_ok=True)
PIN_SCRIPT = str(Path(__file__).parent / "clipboard_pin.py")


def short_hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:16]


def load_pins():
    try:
        res = subprocess.run(
            ["python3", PIN_SCRIPT, "list"], capture_output=True, text=True, check=True
        )
        return json.loads(res.stdout or "[]")
    except Exception:
        return []


def main():
    pinned_items = load_pins()
    # Keys used to dedupe non-image cliphist entries against pinned ones.
    # Image dedup would require decoding every entry — skip for perf.
    pinned_text_keys = {
        p["key"] for p in pinned_items if p["type"] in ("text", "file")
    }

    try:
        result = subprocess.run(
            ["cliphist", "list"], capture_output=True, text=True, check=True
        )
    except subprocess.CalledProcessError:
        print(json.dumps(pinned_items))
        return

    items = list(pinned_items)
    lines = result.stdout.strip().split("\n")

    for line in lines[:20]:
        if not line:
            continue
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue

        cid, data = parts
        is_image = "[[ binary data" in data

        if not is_image:
            key = short_hash(data.encode())
            if key in pinned_text_keys:
                continue

        item = {
            "id": cid,
            "raw": data,
            "line": line,
            "type": "text",
            "preview": "",
            "imagePath": "",
            "filename": "",
            "pinned": False,
        }

        if is_image:
            item["type"] = "image"
            item["preview"] = "Image"
            img_path = TMP_DIR / f"{cid}.png"
            if not img_path.exists():
                try:
                    decode_proc = subprocess.Popen(
                        ["cliphist", "decode", cid],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL,
                    )
                    with open(img_path, "wb") as f:
                        f.write(decode_proc.stdout.read())
                except Exception:
                    pass
            item["imagePath"] = f"file://{img_path}"

        elif data.startswith("file://"):
            item["type"] = "file"
            first_uri = data.split("\n")[0].strip()
            decoded_path = urllib.parse.unquote(first_uri[7:])
            basename = os.path.basename(decoded_path)
            file_count = len([x for x in data.split("\n") if x.strip()])
            if file_count > 1:
                item["filename"] = f"{basename} (+{file_count-1})"
            else:
                item["filename"] = basename
            item["preview"] = first_uri

        else:
            item["type"] = "text"
            preview = data.strip().replace("\n", " ")
            if len(preview) > 100:
                preview = preview[:100] + "..."
            item["preview"] = preview

        items.append(item)

    print(json.dumps(items))


if __name__ == "__main__":
    main()
