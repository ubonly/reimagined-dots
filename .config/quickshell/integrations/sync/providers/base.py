from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class SyncProvider(ABC):
    """Abstract provider contract consumed by SyncManager and the settings UI.

    Real OAuth/device-flow implementations must keep this public API stable so
    the Integration page does not need provider-specific logic.
    """

    provider_id: str
    display_name: str

    def metadata(self) -> dict[str, str]:
        return {
            "id": self.provider_id,
            "displayName": self.display_name,
        }

    def state(self, stored: dict[str, Any] | None) -> dict[str, Any]:
        data = stored or {}
        auth = data.get("auth", {})
        connection_state = str(data.get("connection_state", "not_connected"))

        if isinstance(auth, dict) and auth.get("mock"):
            connection_state = "not_connected"
        if connection_state not in {"not_connected", "connecting", "connected"}:
            connection_state = "not_connected"

        connected = connection_state == "connected"
        return {
            "id": self.provider_id,
            "displayName": self.display_name,
            "connectionState": connection_state,
            "connected": connected,
            "connecting": connection_state == "connecting",
            "username": str(data.get("username", "")) if connected else "",
            "avatar": str(data.get("avatar", "")) if connected else "",
            "repository": str(data.get("repository", "")) if connected else "",
            "lastSync": str(data.get("last_sync", "")) if connected else "",
            "message": str(data.get("message", "")),
            "authSession": data.get("auth_session", {}) if isinstance(data.get("auth_session", {}), dict) else {},
        }

    @abstractmethod
    def connect(self, state: dict[str, Any]) -> dict[str, Any]:
        raise NotImplementedError

    @abstractmethod
    def sync(self, state: dict[str, Any]) -> dict[str, Any]:
        raise NotImplementedError

    @abstractmethod
    def disconnect(self, state: dict[str, Any]) -> dict[str, Any]:
        raise NotImplementedError
