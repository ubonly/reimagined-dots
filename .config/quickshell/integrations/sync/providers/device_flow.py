from __future__ import annotations

from typing import Any

from .base import SyncProvider


class DeviceFlowProvider(SyncProvider):
    """Device-flow shaped provider contract with no fake account data.

    Real token exchange will be added behind this class. Until then, connect()
    keeps the provider disconnected so the UI never invents usernames,
    repositories, or sync timestamps.
    """

    account_host: str

    def connect(self, state: dict[str, Any]) -> dict[str, Any]:
        return {
            "connection_state": "not_connected",
            "username": "",
            "avatar": "",
            "repository": "",
            "last_sync": "",
            "auth": {
                "method": "device_flow",
                "implemented": False,
            },
        }

    def sync(self, state: dict[str, Any]) -> dict[str, Any]:
        data = dict(state)
        if data.get("connection_state") != "connected":
            return self.disconnect(data)
        return data

    def disconnect(self, state: dict[str, Any]) -> dict[str, Any]:
        return {
            "connection_state": "not_connected",
            "username": "",
            "avatar": "",
            "repository": "",
            "last_sync": "",
            "auth": {},
        }
