from __future__ import annotations

from typing import Any

from integrations.phone.kdeconnect_service import KDEConnectService
from integrations.sync.manager import SyncManager


class IntegrationManager:
    def __init__(self) -> None:
        self.sync = SyncManager()
        self.phone = KDEConnectService()

    def snapshot(self) -> dict[str, Any]:
        return {
            "sync": self.sync.snapshot(),
            "phone": self.phone.snapshot(),
        }
