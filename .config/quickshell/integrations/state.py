from __future__ import annotations

import json
from pathlib import Path
from typing import Any


CONFIG_DIR = Path.home() / ".config" / "quickshell"
STATE_PATH = CONFIG_DIR / "integration_state.json"


DEFAULT_STATE: dict[str, Any] = {
    "sync": {
        "active_provider": "",
        "providers": {},
    },
    "phone": {
        "selected_device_id": "",
        "mock_connected": False,
    },
}


def _merge_defaults(raw: dict[str, Any]) -> dict[str, Any]:
    state = json.loads(json.dumps(DEFAULT_STATE))
    for key, value in raw.items():
        if isinstance(value, dict) and isinstance(state.get(key), dict):
            state[key].update(value)
        else:
            state[key] = value
    return state


def load_state() -> dict[str, Any]:
    if not STATE_PATH.exists():
        return json.loads(json.dumps(DEFAULT_STATE))
    try:
        with STATE_PATH.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            return _merge_defaults(data)
    except (OSError, json.JSONDecodeError):
        pass
    return json.loads(json.dumps(DEFAULT_STATE))


def save_state(state: dict[str, Any]) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_PATH.with_suffix(".json.tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    tmp.replace(STATE_PATH)

