#!/usr/bin/env python3
"""preToolUse gate for Write/Edit — allow repo-local source edits, block secrets/outside."""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ALLOWED_REPO_MARKERS = (
    "sotong24work",
    "sotongwarecontrol",
    "sotongwareweb",
)

SECRET_RE = re.compile(
    r"(\.env($|\.|[\\/])|\.pem$|id_rsa|credential|serviceaccount|/secrets?/)",
    re.I,
)

SAFE_EXT_RE = re.compile(
    r"\.(dart|cpp|c|h|hpp|cc|js|ts|tsx|jsx|html|css|scss|json|yaml|yml|md|py|ps1|txt|xml|gradle|kt|swift|cmake|rc|def|idl)$",
    re.I,
)


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _signal(path_hint: str, permission: str, category: str, risk: str) -> None:
    try:
        out = Path.home() / "Documents" / "Sotong24Work" / "Logs" / "cursor_approval_state.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        reason = "안전 편집 자동 진행"
        if permission != "allow":
            if risk == "SECRET":
                reason = "비밀/자격증명 파일 변경 승인이 필요합니다."
            elif risk == "OUTSIDE_WORKSPACE":
                reason = "workspace 밖 파일 수정 승인이 필요합니다."
            else:
                reason = "파일 수정 승인이 필요합니다."
        payload = {
            "schemaVersion": 1,
            "state": "cursor_running" if permission == "allow" else "cursor_waiting_approval",
            "approvalCategory": category,
            "commandOrEditSummary": path_hint[:500],
            "riskCategory": risk,
            "permission": permission,
            "updatedAt": _now_iso(),
            "userActionRequired": permission != "allow",
            "reasonKo": reason,
        }
        out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    except OSError:
        pass


def _tool_path(payload: dict) -> str:
    for key in ("file_path", "filePath", "path", "target_notebook"):
        v = payload.get(key)
        if isinstance(v, str) and v.strip():
            return v.strip()
    tool_input = payload.get("tool_input") or payload.get("input") or {}
    if isinstance(tool_input, dict):
        for key in ("file_path", "filePath", "path", "path"):
            v = tool_input.get(key)
            if isinstance(v, str) and v.strip():
                return v.strip()
    return ""


def classify_write(path: str) -> tuple[str, str, str]:
    p = (path or "").strip()
    low = p.lower().replace("/", "\\")
    if not p:
        # Empty path — fail open for tools that don't provide path in this event.
        return "allow", "SAFE_EDIT", "SAFE"
    if SECRET_RE.search(low):
        return "ask", "SECRET", "SECRET"
    if re.match(r"^[a-z]:\\", low):
        if not any(m in low for m in ALLOWED_REPO_MARKERS):
            # Also allow under Documents\Sotong24Work operational logs/config non-secret
            if "documents\\sotong24work\\" in low and not SECRET_RE.search(low):
                return "allow", "SAFE_EDIT", "SAFE"
            return "ask", "OUTSIDE_WORKSPACE", "OUTSIDE_WORKSPACE"
    # Extension guidance — non-matching still allow inside repo (e.g. BuildStamp.h already covered)
    if SAFE_EXT_RE.search(low) or any(m in low for m in ALLOWED_REPO_MARKERS) or not re.match(r"^[a-z]:\\", low):
        return "allow", "SAFE_EDIT", "SAFE"
    return "ask", "UNKNOWN", "UNKNOWN"


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = {}
    tool = str(payload.get("tool_name") or payload.get("tool") or "").lower()
    # Only gate write-like tools; others pass through.
    if tool and ("write" not in tool and "edit" not in tool and "strreplace" not in tool):
        print(json.dumps({"permission": "allow", "agent_message": "write_gate:skip"}))
        return 0
    path = _tool_path(payload)
    permission, category, risk = classify_write(path)
    _signal(path or tool or "write", permission, category, risk)
    out = {
        "permission": permission,
        "agent_message": f"write_gate:{permission}:{category}:{risk}",
    }
    if permission != "allow":
        out["user_message"] = (
            "Blocked/ask: secret or outside-workspace write requires manual approval."
            if risk in ("SECRET", "OUTSIDE_WORKSPACE")
            else "File write requires manual approval."
        )
    print(json.dumps(out, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
