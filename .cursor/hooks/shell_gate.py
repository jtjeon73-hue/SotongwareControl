#!/usr/bin/env python3
"""Deterministic shell gate for unattended Cursor work.

Only `deny` is reliably enforced by Cursor hooks today. Safe commands return
allow (may still need allowlist). Destructive / production commands are denied.
"""

from __future__ import annotations

import json
import re
import sys


def classify(command: str) -> tuple[str, str]:
    text = (command or "").strip()
    low = text.lower()

    deny_patterns = [
        (r"\brm\s+(-[a-z]*f|/s|/q)", "destructive delete"),
        (r"\brmdir\s+/s", "destructive rmdir"),
        (r"\bdel\s+/[sf]", "destructive del"),
        (r"remove-item\s+.*-recurse", "PowerShell recursive delete"),
        (r"git\s+reset\s+--hard", "git reset --hard"),
        (r"git\s+clean\s+-[a-z]*f", "git clean force"),
        (r"git\s+push\s+.*--force", "force push"),
        (r"git\s+push\s+-f\b", "force push"),
        (r"firebase\s+deploy", "firebase deploy"),
        (r"firebase\s+use\b", "firebase project switch"),
        (r"deploy_.*production|production\s+deploy|site_publish", "production deploy"),
        (r"sotongware\.com|automation\.sotongware\.com", "live site mutation risk"),
        (r"reg\s+add|setx\s+|credential|secret|api[_-]?key", "credential/secret change"),
    ]
    for pat, reason in deny_patterns:
        if re.search(pat, low):
            return "deny", reason

    safe_prefixes = (
        "git status",
        "git diff",
        "git log",
        "git show",
        "git rev-parse",
        "git branch",
        "git fetch",
        "git remote",
        "flutter analyze",
        "flutter test",
        "flutter pub get",
        "dart analyze",
        "dart test",
        "dart format",
        "npm test",
        "npm run test",
        "npm run lint",
        "npm run build",
        "npx ",
        "python scripts/test_",
        "python -m pytest",
        "pytest ",
        "cmake ",
        "ctest ",
        "rg ",
        "dir ",
        "ls ",
        "where ",
        "get-childitem",
        "get-content",
        "select-string",
        "type ",
        "cat ",
        "echo ",
    )
    for prefix in safe_prefixes:
        if low.startswith(prefix) or f" {prefix}" in low:
            return "allow", "safe_dev_command"

    return "ask", "manual_review"


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = {}
    command = str(payload.get("command") or "")
    permission, reason = classify(command)
    out = {
        "permission": permission,
        "agent_message": f"shell_gate:{permission}:{reason}",
    }
    if permission == "deny":
        out["user_message"] = f"Blocked: {reason}. Destructive/deploy commands require manual approval."
    print(json.dumps(out, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
