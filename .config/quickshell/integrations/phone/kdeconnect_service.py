from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from typing import Any, Callable

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib


class KDEConnectService:
    """DBus-backed KDE Connect integration.

    This service is the only layer that talks to KDE Connect. QML receives a
    plain JSON snapshot and never calls DBus directly.
    """

    service_name = "org.kde.kdeconnect"
    devices_root = "/modules/kdeconnect/devices"
    device_iface = "org.kde.kdeconnect.device"
    battery_iface = "org.kde.kdeconnect.device.battery"
    ping_iface = "org.kde.kdeconnect.device.ping"
    share_iface = "org.kde.kdeconnect.device.share"

    def __init__(self) -> None:
        self._bus: dbus.SessionBus | None = None

    @property
    def bus(self) -> dbus.SessionBus:
        if self._bus is None:
            self._bus = dbus.SessionBus()
        return self._bus

    @property
    def installed(self) -> bool:
        return shutil.which("kdeconnectd") is not None or self.daemon_running

    @property
    def daemon_running(self) -> bool:
        try:
            return bool(self.bus.name_has_owner(self.service_name))
        except dbus.DBusException:
            return False

    def _object(self, path: str) -> dbus.proxies.ProxyObject:
        return self.bus.get_object(self.service_name, path)

    def _interface(self, path: str, interface: str) -> dbus.Interface:
        return dbus.Interface(self._object(path), interface)

    def _properties(self, path: str, interface: str) -> dict[str, Any]:
        try:
            props = dbus.Interface(self._object(path), "org.freedesktop.DBus.Properties")
            return {str(key): self._to_python(value) for key, value in props.GetAll(interface).items()}
        except dbus.DBusException:
            return {}

    def _introspect_children(self, path: str) -> list[str]:
        try:
            introspectable = dbus.Interface(self._object(path), "org.freedesktop.DBus.Introspectable")
            root = ET.fromstring(str(introspectable.Introspect()))
        except (dbus.DBusException, ET.ParseError):
            return []
        return [node.attrib["name"] for node in root.findall("node") if "name" in node.attrib]

    def _has_child(self, path: str, child: str) -> bool:
        return child in self._introspect_children(path)

    def _to_python(self, value: Any) -> Any:
        if isinstance(value, dbus.Boolean):
            return bool(value)
        if isinstance(value, (dbus.Int16, dbus.Int32, dbus.Int64, dbus.UInt16, dbus.UInt32, dbus.UInt64)):
            return int(value)
        if isinstance(value, (dbus.String, dbus.ObjectPath, dbus.Signature)):
            return str(value)
        if isinstance(value, (dbus.Array, list, tuple)):
            return [self._to_python(item) for item in value]
        if isinstance(value, (dbus.Dictionary, dict)):
            return {str(key): self._to_python(item) for key, item in value.items()}
        return value

    def _device_paths(self) -> list[str]:
        if not self.daemon_running:
            return []
        return [f"{self.devices_root}/{device_id}" for device_id in self._introspect_children(self.devices_root)]

    def _device_supports(self, path: str, plugin: str) -> bool:
        try:
            iface = self._interface(path, self.device_iface)
            return bool(iface.hasPlugin(plugin))
        except dbus.DBusException:
            return False

    def _device_state(self, props: dict[str, Any]) -> str:
        paired = bool(props.get("isPaired", False))
        reachable = bool(props.get("isReachable", False))
        if paired and reachable:
            return "connected"
        if paired:
            return "disconnected"
        if bool(props.get("isPairRequestedByPeer", False)):
            return "pair_requested"
        if bool(props.get("isPairRequested", False)):
            return "pairing"
        return "device_found"

    def _device_label(self, state: str) -> str:
        return {
            "connected": "Connected",
            "disconnected": "Disconnected",
            "pair_requested": "Pair requested",
            "pairing": "Pairing",
            "device_found": "Device found",
        }.get(state, "Device found")

    def _device_snapshot(self, path: str) -> dict[str, Any] | None:
        props = self._properties(path, self.device_iface)
        if not props:
            return None

        battery_path = f"{path}/battery"
        battery_props = self._properties(battery_path, self.battery_iface) if self._has_child(path, "battery") else {}
        battery_level = battery_props.get("charge")
        battery_available = isinstance(battery_level, int)
        paired = bool(props.get("isPaired", False))
        reachable = bool(props.get("isReachable", False))
        state = self._device_state(props)
        can_ping = paired and reachable and self._device_supports(path, "kdeconnect_ping")
        can_share = paired and reachable and self._device_supports(path, "kdeconnect_share") and self._file_picker() is not None

        # KDE Connect exposes unpair(), but no DBus method for a temporary,
        # non-destructive "disconnect from this device" action. The UI keeps
        # Disconnect disabled instead of mapping it to unpair().
        can_disconnect = False

        return {
            "id": path.rsplit("/", 1)[-1],
            "path": path,
            "name": str(props.get("name", "")),
            "deviceType": str(props.get("type", "unknown")),
            "paired": paired,
            "reachable": reachable,
            "pairRequested": bool(props.get("isPairRequested", False)),
            "pairRequestedByPeer": bool(props.get("isPairRequestedByPeer", False)),
            "pairState": int(props.get("pairState", 0)),
            "state": state,
            "status": self._device_label(state),
            "batteryAvailable": battery_available,
            "batteryLevel": battery_level if battery_available else None,
            "charging": bool(battery_props.get("isCharging", False)) if battery_available else False,
            "actions": {
                "pair": reachable and not paired,
                "unpair": paired,
                "ping": can_ping,
                "sendFile": can_share,
                "disconnect": can_disconnect,
            },
            "unsupported": {
                "disconnect": "KDE Connect DBus does not expose a non-destructive disconnect method.",
            },
        }

    def _overall_state(self, devices: list[dict[str, Any]]) -> str:
        if not self.installed:
            return "unavailable"
        if not self.daemon_running:
            return "unavailable"
        if not devices:
            return "searching"
        if any(device["state"] == "connected" for device in devices):
            return "connected"
        if any(device["paired"] for device in devices):
            return "disconnected"
        return "device_found"

    def _message(self, devices: list[dict[str, Any]]) -> str:
        if not self.installed:
            return "KDE Connect is not installed."
        if not self.daemon_running:
            return "KDE Connect daemon is not running."
        if not devices:
            return "No KDE Connect devices were found."
        return ""

    def snapshot(self) -> dict[str, Any]:
        devices = []
        if self.installed and self.daemon_running:
            for path in self._device_paths():
                device = self._device_snapshot(path)
                if device is not None:
                    devices.append(device)

        state = self._overall_state(devices)
        first_connected = next((device for device in devices if device["state"] == "connected"), devices[0] if devices else None)
        return {
            "installed": self.installed,
            "daemonRunning": self.daemon_running,
            "available": self.installed and self.daemon_running,
            "state": state,
            "message": self._message(devices),
            "devices": devices,
            "canRefresh": self.installed,
            "canOpen": self.installed,
            "canInstall": not self.installed,
            # Compatibility fields for older UI bindings.
            "connected": any(device["state"] == "connected" for device in devices),
            "deviceName": first_connected["name"] if first_connected else "",
            "batteryLevel": f"{first_connected['batteryLevel']}%" if first_connected and first_connected["batteryAvailable"] else "",
            "deviceType": first_connected["deviceType"] if first_connected else "",
        }

    def _device_path(self, device_id: str) -> str:
        return f"{self.devices_root}/{device_id}"

    def refresh(self) -> dict[str, Any]:
        return self.snapshot()

    def open_kde_connect(self) -> dict[str, Any]:
        for command in (shutil.which("kdeconnect-app"), shutil.which("kdeconnect-indicator")):
            if command:
                subprocess.Popen([command], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                break
        return self.snapshot()

    def install_kde_connect(self) -> dict[str, Any]:
        data = self.snapshot()
        data["message"] = "Install KDE Connect with your distribution package manager."
        return data

    def pair(self, device_id: str) -> dict[str, Any]:
        self._interface(self._device_path(device_id), self.device_iface).requestPairing()
        return self.snapshot()

    def unpair(self, device_id: str) -> dict[str, Any]:
        self._interface(self._device_path(device_id), self.device_iface).unpair()
        return self.snapshot()

    def ping(self, device_id: str) -> dict[str, Any]:
        self._interface(f"{self._device_path(device_id)}/ping", self.ping_iface).sendPing()
        return self.snapshot()

    def disconnect(self, device_id: str) -> dict[str, Any]:
        data = self.snapshot()
        data["message"] = "KDE Connect DBus does not expose a non-destructive disconnect method."
        return data

    def _file_picker(self) -> str | None:
        return shutil.which("zenity")

    def send_file(self, device_id: str) -> dict[str, Any]:
        picker = self._file_picker()
        if picker is None:
            data = self.snapshot()
            data["message"] = "No supported file picker is installed."
            return data

        result = subprocess.run(
            [picker, "--file-selection"],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        path = result.stdout.strip()
        if result.returncode != 0 or not path:
            return self.snapshot()
        self._interface(f"{self._device_path(device_id)}/share", self.share_iface).openFile(os.path.abspath(path))
        return self.snapshot()

    def watch(self, emit: Callable[[dict[str, Any]], None]) -> None:
        DBusGMainLoop(set_as_default=True)
        self._bus = dbus.SessionBus()
        loop = GLib.MainLoop()
        last_payload = ""
        pending = {"source": 0}

        def emit_snapshot() -> bool:
            pending["source"] = 0
            nonlocal last_payload
            payload = json.dumps(self.snapshot(), ensure_ascii=False, sort_keys=True)
            if payload != last_payload:
                last_payload = payload
                emit(json.loads(payload))
            return False

        def schedule_emit(*_args: Any, **_kwargs: Any) -> None:
            if pending["source"] == 0:
                pending["source"] = GLib.timeout_add(100, emit_snapshot)

        def name_owner_changed(name: str, _old: str, _new: str) -> None:
            if name == self.service_name:
                schedule_emit()

        self.bus.add_signal_receiver(
            name_owner_changed,
            signal_name="NameOwnerChanged",
            dbus_interface="org.freedesktop.DBus",
            bus_name="org.freedesktop.DBus",
            path="/org/freedesktop/DBus",
        )
        self.bus.add_signal_receiver(
            schedule_emit,
            signal_name="PropertiesChanged",
            dbus_interface="org.freedesktop.DBus.Properties",
            sender_keyword="sender",
            path_keyword="path",
        )
        for signal in ("reachableChanged", "pairStateChanged", "nameChanged", "typeChanged", "pluginsChanged", "linksChanged", "refreshed"):
            self.bus.add_signal_receiver(schedule_emit, signal_name=signal, sender_keyword="sender", path_keyword="path")

        # KDE Connect does not expose org.freedesktop.DBus.ObjectManager on the
        # devices root, so brand-new object paths cannot be discovered solely by
        # InterfacesAdded. A slow fallback re-introspects the devices root while
        # DBus signals handle normal property updates.
        GLib.timeout_add_seconds(15, emit_snapshot)
        emit_snapshot()
        loop.run()

