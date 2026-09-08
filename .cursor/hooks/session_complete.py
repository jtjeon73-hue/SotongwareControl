#!/usr/bin/env python3
"""Cursor stop hook — mark unattended session completed for FCM (deduped by heartbeat)."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def main() -> int:
    # Consume stdin (may be empty / large).
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
            "reasonKo": "Cursor 무인 작업이 완료되었습니다. Control에서 결과를 확인해 주세요.",
        }
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    except OSError:
        pass
    print(json.dumps({"continue": True}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
