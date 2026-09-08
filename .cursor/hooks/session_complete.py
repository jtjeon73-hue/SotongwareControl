#!/usr/bin/env python3
"""Cursor stop hook — mark unattended session completed for FCM (deduped by heartbeat)."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def main() -> int:
    try:
        sys.stdin.read()
    except Exception:
        pass
    path = Path.home() / "Documents" / "Sotong24Work" / "Logs" / "cursor_approval_state.json"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "schemaVersion": 1,
            "state": "cursor_completed",
            "approvalCategory": "SAFE_EDIT",
            "commandOrEditSummary": "agent_session_stop",
            "riskCategory": "SAFE",
            "permission": "allow",
            "updatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
            "userActionRequired": False,
            "reasonKo": (
                "Cursor \ubb34\uc778 \uc791\uc5c5\uc774 \uc644\ub8cc\ub418\uc5c8\uc2b5\ub2c8\ub2e4. "
                "Control\uc5d0\uc11c \uacb0\uacfc\ub97c \ud655\uc778\ud574 \uc8fc\uc138\uc694."
            ),
        }
        path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    except OSError:
        pass
    print(json.dumps({"continue": True}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
