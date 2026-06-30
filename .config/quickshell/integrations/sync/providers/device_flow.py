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
            "connection_state": "connecting",
            "username": "",
            "avatar": "",
            "repository": "",
            "last_sync": "",
            "message": "OAuth Device Flow is not implemented yet.",
            "auth_session": {
                "method": "device_flow",
                "provider": self.provider_id,
                "verification_uri": "",
                "user_code": "",
                "device_code": "",
                "expires_at": "",
                "implemented": False,
            },
            "auth": {
                "method": "device_flow",
                "implemented": False,
            },
        }

    def sync(self, state: dict[str, Any]) -> dict[str, Any]:
        data = dict(state)
        if data.get("connection_state") != "connected":
            return data
        return data

    def disconnect(self, state: dict[str, Any]) -> dict[str, Any]:
        return {
            "connection_state": "not_connected",
            "username": "",
            "avatar": "",
            "repository": "",
            "last_sync": "",
            "message": "",
            "auth_session": {},
            "auth": {},
        }
