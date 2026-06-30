from __future__ import annotations

from typing import Any

from integrations.state import load_state, save_state
from integrations.sync.providers import PROVIDERS
from integrations.sync.providers.base import SyncProvider


class SyncManager:
    def __init__(self) -> None:
        self._providers: dict[str, SyncProvider] = {
            provider.provider_id: provider for provider in PROVIDERS
        }

    @property
    def providers(self) -> list[dict[str, str]]:
        return [provider.metadata() for provider in self._providers.values()]

    def _provider(self, provider_id: str) -> SyncProvider:
        if provider_id not in self._providers:
            raise ValueError(f"Unknown sync provider: {provider_id}")
        return self._providers[provider_id]

    def _default_provider_id(self) -> str:
        return next(iter(self._providers), "")

    def _selected_provider_id(self, sync_state: dict[str, Any]) -> str:
        selected = str(sync_state.get("active_provider", ""))
        if selected in self._providers:
            return selected
        return self._default_provider_id()

    def _empty_status(self, provider: SyncProvider | None = None) -> dict[str, Any]:
        if provider:
            return provider.state({})
        return {
            "id": "",
            "displayName": "None",
            "connectionState": "not_connected",
            "connected": False,
            "connecting": False,
            "username": "",
            "avatar": "",
            "repository": "",
            "lastSync": "",
        }

    def snapshot(self) -> dict[str, Any]:
        state = load_state()
        sync_state = state["sync"]
        active_id = self._selected_provider_id(sync_state)
        provider_states = sync_state.get("providers", {})
        active = self._providers.get(active_id)
        status = active.state(provider_states.get(active_id, {})) if active else self._empty_status()

        return {
            "providers": self.providers,
            "activeProvider": active_id,
            "status": status,
        }

    def select_provider(self, provider_id: str) -> dict[str, Any]:
        self._provider(provider_id)
        state = load_state()
        state["sync"]["active_provider"] = provider_id
        save_state(state)
        return self.snapshot()

    def connect(self, provider_id: str) -> dict[str, Any]:
        provider = self._provider(provider_id)
        state = load_state()
        sync_state = state["sync"]

        for known_provider in self._providers:
            if known_provider != provider_id:
                sync_state.setdefault("providers", {})[known_provider] = self._providers[known_provider].disconnect({})

        sync_state["active_provider"] = provider_id
        sync_state.setdefault("providers", {})[provider_id] = provider.connect(
            sync_state.get("providers", {}).get(provider_id, {})
        )
        save_state(state)
        return self.snapshot()

    def sync(self) -> dict[str, Any]:
        state = load_state()
        active_id = self._selected_provider_id(state["sync"])
        if not active_id:
            return self.snapshot()

        provider = self._provider(active_id)
        provider_state = state["sync"].setdefault("providers", {}).get(active_id, {})
        state["sync"]["providers"][active_id] = provider.sync(provider_state)
        save_state(state)
        return self.snapshot()

    def disconnect(self) -> dict[str, Any]:
        state = load_state()
        active_id = state["sync"].get("active_provider", "")
        if active_id in self._providers:
            state["sync"].setdefault("providers", {})[active_id] = self._providers[active_id].disconnect({})
        state["sync"]["active_provider"] = ""
        save_state(state)
        return self.snapshot()
