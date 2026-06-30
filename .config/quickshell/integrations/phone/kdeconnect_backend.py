from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from typing import Any

from integrations.state import load_state, save_state


@dataclass
class PhoneDevice:
    device_id: str
    name: str
    device_type: str = "Phone"
    battery: str = "Unknown"


class KDEConnectBackend:
    """Reusable KDE Connect backend.

    The backend currently uses kdeconnect-cli as a stable local bridge and keeps
    all DBus-facing behavior out of QML. Direct DBus support can replace the CLI
    calls behind this same public API.
    """

    dbus_service = "org.kde.kdeconnect"

    def __init__(self) -> None:
        self._cli = shutil.which("kdeconnect-cli")

    @property
    def available(self) -> bool:
        return self._cli is not None

    def _run(self, *args: str) -> str:
        if not self._cli:
            return ""
        try:
            result = subprocess.run(
                [self._cli, *args],
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=3,
            )
        except (OSError, subprocess.TimeoutExpired):
            return ""
        return result.stdout.strip()

    def _with_details(self, device: PhoneDevice) -> PhoneDevice:
        raw = self._run("--device", device.device_id, "--status")
        for line in raw.splitlines():
            normalized = line.strip()
            if not normalized:
                continue
            key, _, value = normalized.partition(":")
            key = key.strip().lower()
            value = value.strip()
            if not value:
                continue
            if key in {"battery", "battery level"}:
                device.battery = value
            elif key in {"type", "device type"}:
                device.device_type = value
        return device

    def _available_devices(self) -> list[PhoneDevice]:
        raw = self._run("--list-devices", "--id-name-only")
        if not raw:
            raw = self._run("--list-available", "--id-name-only")
        devices: list[PhoneDevice] = []
        for line in raw.splitlines():
            line = line.strip()
            if not line:
                continue
            parts = line.split(maxsplit=1)
            if len(parts) == 1:
                devices.append(PhoneDevice(device_id=parts[0], name=parts[0]))
            else:
                devices.append(PhoneDevice(device_id=parts[0], name=parts[1]))
        return [self._with_details(device) for device in devices]

    def _message(self, selected: PhoneDevice | None) -> str:
        if not self.available:
            return "KDE Connect is not installed or is not available."
        if selected is None:
            return "No KDE Connect phone is paired yet. Pair a phone from KDE Connect to enable this integration."
        return ""

    def snapshot(self) -> dict[str, Any]:
        state = load_state()
        phone_state = state["phone"]
        devices = self._available_devices() if self.available else []
        selected_id = phone_state.get("selected_device_id", "")
        selected = next((device for device in devices if device.device_id == selected_id), None)
        if selected is None and devices:
            selected = devices[0]

        connected = selected is not None
        return {
            "available": self.available,
            "connected": connected,
            "deviceName": selected.name if selected else "",
            "batteryLevel": selected.battery if selected else "",
            "deviceType": selected.device_type if selected else "",
            "message": self._message(selected),
        }

    def connect(self) -> dict[str, Any]:
        state = load_state()
        if self.available:
            self._run("--refresh")
            devices = self._available_devices()
            if devices:
                state["phone"]["selected_device_id"] = devices[0].device_id
                state["phone"]["mock_connected"] = False
                save_state(state)
                return self.snapshot()

        save_state(state)
        return self.snapshot()

    def disconnect(self) -> dict[str, Any]:
        state = load_state()
        state["phone"]["selected_device_id"] = ""
        state["phone"]["mock_connected"] = False
        save_state(state)
        return self.snapshot()
