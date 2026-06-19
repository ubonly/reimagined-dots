#!/usr/bin/env python3
import os
import glob
import json
from datetime import datetime
import mimetypes
from pathlib import Path

def get_icon_for_file(path):
    mime_type, _ = mimetypes.guess_type(path)
    if not mime_type:
        return "unknown"
    if mime_type.startswith("image/"):
        return "image-x-generic"
    elif mime_type.startswith("video/"):
        return "video-x-generic"
    elif mime_type.startswith("text/"):
        return "text-x-generic"
    elif mime_type == "application/pdf":
        return "application-pdf"
    elif mime_type.startswith("audio/"):
        return "audio-x-generic"
    return "text-x-generic"

def format_date(ts):
    dt = datetime.fromtimestamp(ts)
    return f"You edited • {dt.strftime('%b %-d')}"

def main():
    home = str(Path.home())
    dirs_to_check = [
        os.path.join(home, "Downloads"),
        os.path.join(home, "Documents"),
        os.path.join(home, "Pictures")
    ]
    
    files = []
    for d in dirs_to_check:
        if not os.path.exists(d):
            continue
        # get all files in these directories (non-recursive for speed)
        for entry in os.scandir(d):
            if entry.is_file() and not entry.name.startswith('.'):
                stat = entry.stat()
                files.append({
                    "path": entry.path,
                    "name": entry.name,
                    "mtime": stat.st_mtime
                })
                
    # sort by mtime descending
    files.sort(key=lambda x: x["mtime"], reverse=True)
    
    # take top 4
    top_files = files[:4]
    
    result = []
    for f in top_files:
        result.append({
            "name": f["name"],
            "date": format_date(f["mtime"]),
            "icon": get_icon_for_file(f["path"]),
            "exec": f"xdg-open '{f['path']}'"
        })
        
    print(json.dumps(result))

if __name__ == "__main__":
    main()
