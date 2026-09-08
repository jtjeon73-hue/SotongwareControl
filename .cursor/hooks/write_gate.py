#!/usr/bin/env python3
"""preToolUse Write/Edit gate — Phase 4.1 fail-closed + Golden/WI/path containment."""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

POLICY_VERSION = "phase4.1-hardening"

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

GOLDEN_WI_RE = re.compile(
    r"("
    r"wi_plan_1788707699582|"
    r"wi_wi_plan_1788707699582|"
    r"[\\/]State[\\/]wi_|"
    r"[\\/]EbookProjects[\\/]wi_plan_|"
    r"[\\/]Instructions[\\/]|"
    r"cursor_approval_state\.json|"
    r"remote_received_requests\.json|"
    r"remote_processed_requests\.json|"
    r"approval_poll_context\.json|"
    r"current_work\.json"
    r")",
    re.I,
)

WEB_MARKER = "sotongwareweb"


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
            elif category == "USER_GOLDEN_RUN":
                reason = "Golden Run / WI / review state 변경은 자동 승인 금지입니다."
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


def _allowed_roots() -> list[Path]:
    home = Path.home()
    roots: list[Path] = []
    for rel in (
        home / "Documents" / "GitHub" / "Sotong24Work",
        home / "Documents" / "GitHub" / "SotongwareControl",
        home / "Documents" / "Sotong24Work",
    ):
        try:
            if rel.exists():
                roots.append(rel.resolve())
            else:
                roots.append(rel)
        except OSError:
            roots.append(rel)
    return roots


def _is_under_allowed_root(path: Path) -> bool:
    try:
        resolved = path.resolve()
    except (OSError, RuntimeError):
        return False
    for root in _allowed_roots():
        try:
            r = root.resolve()
        except (OSError, RuntimeError):
            r = root
        if resolved == r or r in resolved.parents:
            return True
    return False


def classify_write(path: str) -> tuple[str, str, str]:
    p = (path or "").strip()
    if not p:
        # fail-closed: empty/invalid path
        return "ask", "UNKNOWN", "UNKNOWN"

    low = p.lower().replace("/", "\\")
    if SECRET_RE.search(low):
        return "ask", "USER_SECRET", "SECRET"
    if GOLDEN_WI_RE.search(low):
        return "ask", "USER_GOLDEN_RUN", "PRODUCTION"
    if WEB_MARKER in low:
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE"

    if ".." in Path(p).parts:
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE"

    if re.match(r"^[a-zA-Z]:[\\/]", p):
        try:
            resolved = Path(p).resolve()
        except (OSError, RuntimeError):
            return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE"
        low_res = str(resolved).lower().replace("/", "\\")
        if SECRET_RE.search(low_res):
            return "ask", "USER_SECRET", "SECRET"
        if GOLDEN_WI_RE.search(low_res):
            return "ask", "USER_GOLDEN_RUN", "PRODUCTION"
        if WEB_MARKER in low_res:
            return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE"
        if _is_under_allowed_root(resolved):
            return "allow", "SAFE_EDIT", "SAFE"
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE"

    # Relative paths: workspace-local for multi-root Work/Control.
    return "allow", "SAFE_EDIT", "SAFE"


def _fail_closed(reason: str) -> int:
    out = {
        "permission": "ask",
        "agent_message": f"write_gate:ask:UNKNOWN:{reason}",
        "user_message": "Hook fail-closed: 불확실한 write는 자동 실행하지 않습니다.",
    }
    _audit(
        {
            "ts": _now_iso(),
            "hook": "write_gate",
            "tool": "",
            "path": "",
            "permission": "ask",
            "category": "UNKNOWN",
            "risk": "UNKNOWN",
            "reason": reason,
            "policySource": "Sotong24Work/.cursor/hooks/write_gate.py",
            "policyVersion": POLICY_VERSION,
            "failClosed": True,
        }
    )
    _signal(reason, "ask", "UNKNOWN", "UNKNOWN")
    print(json.dumps(out, ensure_ascii=True))
    return 0


def main() -> int:
    raw = sys.stdin.read()
    try:
        if not raw.strip():
            return _fail_closed("empty_stdin")
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            return _fail_closed("malformed_json")
        if not isinstance(payload, dict):
            return _fail_closed("invalid_payload_type")

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
                "policyVersion": POLICY_VERSION,
            }
        )
        out = {
            "permission": permission,
            "agent_message": f"write_gate:{permission}:{category}:{risk}",
        }
        if permission != "allow":
            out["user_message"] = (
                "Blocked/ask: secret, Golden/WI, or outside-workspace/Web write requires approval."
            )
        print(json.dumps(out, ensure_ascii=True))
        return 0
    except Exception as exc:  # noqa: BLE001 — fail-closed
        return _fail_closed(f"exception:{type(exc).__name__}")


if __name__ == "__main__":
    raise SystemExit(main())
