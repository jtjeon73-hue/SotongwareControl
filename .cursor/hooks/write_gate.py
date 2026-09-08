#!/usr/bin/env python3
"""preToolUse Write/Edit gate — Work/Control auto; Web/secret/outside ask."""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ALLOWED_ABS_ROOTS = (
    r"documents\github\sotong24work",
    r"documents\github\sotongwarecontrol",
    r"documents\sotong24work",
)

WEB_MARKER = "sotongwareweb"

SECRET_RE = re.compile(
    r"("
    r"\.env($|\.|[\\/])|"
    r"\.pem$|id_rsa|"
    r"credential|service.?account|"
    r"[\\/]secrets?[\\/]|"
    r"keystore|\.jks$|"
    r"deploy_control\.local\.ps1"
    r")",
    re.I,
)


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _audit(entry: dict) -> None:
    try:
        path = Path.home() / "Documents" / "Sotong24Work" / "Logs" / "cursor_gate_audit.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except OSError:
        pass


def _signal(path_hint: str, permission: str, category: str, risk: str) -> None:
    try:
        out = Path.home() / "Documents" / "Sotong24Work" / "Logs" / "cursor_approval_state.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        reason = "안전 편집 자동 진행"
        if permission != "allow":
            if risk == "SECRET":
                reason = "비밀/자격증명 파일 변경 승인이 필요합니다."
            elif risk == "OUTSIDE_WORKSPACE":
                reason = "허용 repo 밖/Web 파일 수정 승인이 필요합니다."
            else:
                reason = f"파일 수정 승인이 필요합니다. ({category}/{risk})"
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
        for key in ("file_path", "filePath", "path"):
            v = tool_input.get(key)
            if isinstance(v, str) and v.strip():
                return v.strip()
    return ""


def _canonical(path: str) -> str:
    try:
        return str(Path(path).resolve()).lower().replace("/", "\\")
    except OSError:
        return path.lower().replace("/", "\\")


def _in_allowed_root(low: str) -> bool:
    return any(root in low for root in ALLOWED_ABS_ROOTS)


def classify_write(path: str) -> tuple[str, str, str]:
    p = (path or "").strip()
    if not p:
        return "allow", "SAFE_EDIT", "SAFE"
    low = _canonical(p) if re.match(r"^[a-zA-Z]:[\\/]", p) else p.lower().replace("/", "\\")
    if SECRET_RE.search(low):
        return "ask", "USER_SECRET", "SECRET"
    if WEB_MARKER in low:
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE"
    if re.match(r"^[a-z]:\\", low):
        if _in_allowed_root(low):
            return "allow", "SAFE_EDIT", "SAFE"
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE"
    # Relative paths: workspace-local for multi-root Work/Control.
    if ".." in Path(p).parts:
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE"
    return "allow", "SAFE_EDIT", "SAFE"


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = {}
    tool = str(payload.get("tool_name") or payload.get("tool") or "").lower()
    if tool and ("write" not in tool and "edit" not in tool and "strreplace" not in tool):
        print(json.dumps({"permission": "allow", "agent_message": "write_gate:skip"}))
        return 0
    path = _tool_path(payload)
    permission, category, risk = classify_write(path)
    _signal(path or tool or "write", permission, category, risk)
    _audit(
        {
            "ts": _now_iso(),
            "hook": "write_gate",
            "tool": tool,
            "path": path[:500],
            "permission": permission,
            "category": category,
            "risk": risk,
            "policySource": "Sotong24Work/.cursor/hooks/write_gate.py",
            "policyVersion": "phase4-final",
        }
    )
    out = {
        "permission": permission,
        "agent_message": f"write_gate:{permission}:{category}:{risk}",
    }
    if permission != "allow":
        out["user_message"] = (
            "Blocked/ask: secret or outside-workspace/Web write requires manual approval."
        )
    print(json.dumps(out, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
