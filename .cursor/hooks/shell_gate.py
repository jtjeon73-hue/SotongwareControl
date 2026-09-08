#!/usr/bin/env python3
"""Deterministic shell gate for unattended Cursor work (phase-2).

Only `deny` is hard-enforced by Cursor hooks. Safe repo-local commands return
allow (also requires allowlist). Destructive / production / unknown risky
commands return deny or ask, and ask/deny writes an approval-waiting signal.
"""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


ALLOWED_REPO_MARKERS = (
    "sotong24work",
    "sotongwarecontrol",
    "sotongwareweb",
)

SECRET_PATH_RE = re.compile(
    r"(\.env($|\.|[\\/])|\.pem$|id_rsa|credential|serviceaccount|secrets?[\\/])",
    re.I,
)


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _signal_path() -> Path:
    home = Path.home()
    return home / "Documents" / "Sotong24Work" / "Logs" / "cursor_approval_state.json"


def write_approval_signal(
    *,
    state: str,
    category: str,
    summary: str,
    risk: str,
    permission: str,
) -> None:
    path = _signal_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "schemaVersion": 1,
            "state": state,  # cursor_waiting_approval | cursor_running | cursor_completed
            "approvalCategory": category,
            "commandOrEditSummary": summary[:500],
            "riskCategory": risk,
            "permission": permission,
            "updatedAt": _now_iso(),
            "userActionRequired": permission in ("ask", "deny"),
            "reasonKo": _reason_ko(category, risk, permission),
        }
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    except OSError:
        pass


def _reason_ko(category: str, risk: str, permission: str) -> str:
    if permission == "allow":
        return "안전 작업 자동 진행"
    if risk == "PRODUCTION":
        return "운영 배포 승인이 필요해 작업이 안전 정지되었습니다."
    if risk == "DESTRUCTIVE":
        return "파괴적 작업 승인이 필요해 작업이 안전 정지되었습니다."
    if risk == "SECRET":
        return "비밀/자격증명 변경 승인이 필요해 작업이 안전 정지되었습니다."
    if risk == "OUTSIDE_WORKSPACE":
        return "workspace 밖 파일 작업 승인이 필요합니다."
    if category == "USER_DECISION":
        return "사용자 결과물 검토/의사결정이 필요합니다."
    return f"Cursor 승인 대기 ({category}/{risk})"


def _paths_in_allowed_repos(command: str) -> bool:
    low = command.lower().replace("/", "\\")
    # Prefer explicit markers over cwd-only heuristics.
    hits = [m for m in ALLOWED_REPO_MARKERS if m in low]
    if not hits:
        # Relative paths with no absolute drive letters: treat as workspace-local.
        if re.search(r"[a-z]:\\", low):
            return False
        return True
    # If absolute paths exist, every absolute path must include an allowed marker.
    abs_paths = re.findall(r"[a-z]:\\[^\s\"']+", low)
    if not abs_paths:
        return True
    return all(any(m in p for m in ALLOWED_REPO_MARKERS) for p in abs_paths)


def _has_secret_path(command: str) -> bool:
    return bool(SECRET_PATH_RE.search(command))


def classify(command: str) -> tuple[str, str, str, str]:
    """Return (permission, category, risk, reason)."""
    text = (command or "").strip()
    low = text.lower()

    deny_patterns = [
        (r"\brm\s+(-[a-z]*f|/s|/q)", "DESTRUCTIVE", "destructive delete"),
        (r"\brmdir\s+/s", "DESTRUCTIVE", "destructive rmdir"),
        (r"\bdel\s+/[sf]", "DESTRUCTIVE", "destructive del"),
        (r"remove-item\s+.*-recurse", "DESTRUCTIVE", "PowerShell recursive delete"),
        (r"remove-item\b", "DESTRUCTIVE", "PowerShell delete"),
        (r"git\s+reset\s+--hard", "DESTRUCTIVE", "git reset --hard"),
        (r"git\s+clean\s+-[a-z]*f", "DESTRUCTIVE", "git clean force"),
        (r"git\s+push\s+.*--force", "DESTRUCTIVE", "force push"),
        (r"git\s+push\s+-f\b", "DESTRUCTIVE", "force push"),
        (r"git\s+push\b", "PRODUCTION", "git push gated"),
        (r"firebase\s+deploy", "PRODUCTION", "firebase deploy"),
        (r"firebase\s+use\b", "PRODUCTION", "firebase project switch"),
        (r"deploy_.*production|production\s+deploy|site_publish", "PRODUCTION", "production deploy"),
        (r"sotongware\.com|automation\.sotongware\.com", "PRODUCTION", "live site mutation risk"),
        (r"\bsetx\s+|reg\s+add", "SECRET", "credential/env mutation"),
    ]
    for pat, risk, reason in deny_patterns:
        if re.search(pat, low):
            return "deny", risk, risk, reason

    if _has_secret_path(text):
        return "ask", "SECRET", "SECRET", "secret_path_touch"

    # Safe in-repo copy/move/rename/new-item
    if re.search(r"\b(copy-item|move-item|rename-item|new-item)\b", low):
        if not _paths_in_allowed_repos(text):
            return "ask", "OUTSIDE_WORKSPACE", "OUTSIDE_WORKSPACE", "copy_outside_allowed_repos"
        if re.search(r"\b(c:\\windows|appdata\\roaming|\\ssh\\|credential)\b", low):
            return "ask", "SECRET", "SECRET", "sensitive_copy_target"
        return "allow", "SAFE_COPY", "SAFE", "safe_repo_copy_or_move"

    safe_prefixes = (
        ("git status", "SAFE_READ"),
        ("git diff", "SAFE_READ"),
        ("git log", "SAFE_READ"),
        ("git show", "SAFE_READ"),
        ("git rev-parse", "SAFE_READ"),
        ("git branch", "SAFE_READ"),
        ("git fetch", "SAFE_READ"),
        ("git remote", "SAFE_READ"),
        ("git add", "SAFE_EDIT"),
        ("git commit", "SAFE_EDIT"),
        ("flutter analyze", "SAFE_TEST"),
        ("flutter test", "SAFE_TEST"),
        ("flutter pub get", "SAFE_BUILD"),
        ("dart analyze", "SAFE_TEST"),
        ("dart test", "SAFE_TEST"),
        ("dart format", "SAFE_EDIT"),
        ("npm test", "SAFE_TEST"),
        ("npm run test", "SAFE_TEST"),
        ("npm run lint", "SAFE_TEST"),
        ("npm run build", "SAFE_BUILD"),
        ("npx ", "SAFE_TEST"),
        ("python scripts/test_", "SAFE_TEST"),
        ("python -m pytest", "SAFE_TEST"),
        ("pytest ", "SAFE_TEST"),
        ("cmake ", "SAFE_BUILD"),
        ("ctest ", "SAFE_TEST"),
        ("msbuild ", "SAFE_BUILD"),
        ("dotnet ", "SAFE_BUILD"),
        ("rg ", "SAFE_READ"),
        ("dir ", "SAFE_READ"),
        ("ls ", "SAFE_READ"),
        ("where ", "SAFE_READ"),
        ("get-childitem", "SAFE_READ"),
        ("get-content", "SAFE_READ"),
        ("select-string", "SAFE_READ"),
        ("get-filehash", "SAFE_READ"),
        ("get-process", "SAFE_READ"),
        ("get-ciminstance", "SAFE_READ"),
        ("test-path", "SAFE_READ"),
        ("type ", "SAFE_READ"),
        ("cat ", "SAFE_READ"),
        ("echo ", "SAFE_READ"),
    )
    for prefix, category in safe_prefixes:
        if low.startswith(prefix) or f";{prefix}" in low.replace(" ", "") or f" {prefix}" in low:
            return "allow", category, "SAFE", "safe_dev_command"

    return "ask", "UNKNOWN", "UNKNOWN", "manual_review"


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = {}
    command = str(payload.get("command") or "")
    permission, category, risk, reason = classify(command)
    if permission in ("ask", "deny"):
        write_approval_signal(
            state="cursor_waiting_approval",
            category=category,
            summary=command,
            risk=risk,
            permission=permission,
        )
    else:
        write_approval_signal(
            state="cursor_running",
            category=category,
            summary=command[:120],
            risk=risk,
            permission=permission,
        )

    out = {
        "permission": permission,
        "agent_message": f"shell_gate:{permission}:{category}:{reason}",
    }
    if permission == "deny":
        out["user_message"] = (
            f"Blocked: {reason}. Destructive/deploy/secret commands require manual approval."
        )
    elif permission == "ask":
        out["user_message"] = _reason_ko(category, risk, permission)
    print(json.dumps(out, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
