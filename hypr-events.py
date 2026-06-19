#!/usr/bin/env python3
"""Listen to Hyprland socket2 events and print them line by line."""
import socket, os, sys

sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
path = f"{xdg}/hypr/{sig}/.socket2.sock"

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(path)
# Unbuffered output
f = sock.makefile("r")
for line in f:
    sys.stdout.write(line)
    sys.stdout.flush()
