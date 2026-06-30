#!/usr/bin/env python3
from __future__ import annotations

import json
import sys

from integrations.manager import IntegrationManager


def print_json(payload: object) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    sys.stdout.flush()


def main(argv: list[str]) -> int:
    manager = IntegrationManager()
    command = argv[1] if len(argv) > 1 else "state"

    try:
        if command == "state":
            print_json(manager.snapshot())
        elif command == "sync-select":
            provider_id = argv[2] if len(argv) > 2 else ""
            print_json({"sync": manager.sync.select_provider(provider_id), "phone": manager.phone.snapshot()})
        elif command == "sync-connect":
            provider_id = argv[2] if len(argv) > 2 else ""
            print_json({"sync": manager.sync.connect(provider_id), "phone": manager.phone.snapshot()})
        elif command in {"sync", "sync-now"}:
            print_json({"sync": manager.sync.sync(), "phone": manager.phone.snapshot()})
        elif command == "sync-disconnect":
            print_json({"sync": manager.sync.disconnect(), "phone": manager.phone.snapshot()})
        elif command == "phone-refresh":
            print_json({"sync": manager.sync.snapshot(), "phone": manager.phone.refresh()})
        elif command == "phone-open":
            print_json({"sync": manager.sync.snapshot(), "phone": manager.phone.open_kde_connect()})
        elif command == "phone-install":
            print_json({"sync": manager.sync.snapshot(), "phone": manager.phone.install_kde_connect()})
        elif command == "phone-pair":
            print_json({"sync": manager.sync.snapshot(), "phone": manager.phone.pair(argv[2])})
        elif command == "phone-unpair":
            print_json({"sync": manager.sync.snapshot(), "phone": manager.phone.unpair(argv[2])})
        elif command == "phone-ping":
            print_json({"sync": manager.sync.snapshot(), "phone": manager.phone.ping(argv[2])})
        elif command == "phone-send-file":
            print_json({"sync": manager.sync.snapshot(), "phone": manager.phone.send_file(argv[2])})
        elif command == "phone-disconnect":
            print_json({"sync": manager.sync.snapshot(), "phone": manager.phone.disconnect(argv[2])})
        elif command == "phone-connect":
            print_json({"sync": manager.sync.snapshot(), "phone": manager.phone.refresh()})
        elif command == "watch-phone":
            manager.phone.watch(lambda phone: print_json({"phone": phone}))
        else:
            raise ValueError(f"Unknown command: {command}")
    except Exception as exc:
        print_json({"error": str(exc), **manager.snapshot()})
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
