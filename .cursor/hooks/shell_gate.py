#!/usr/bin/env python3
"""Deterministic shell gate — Unattended Operations FINAL (phase-4).

SAFE → allow (no Run prompt from this hook)
USER_* / DESTRUCTIVE / SECRET / PRODUCTION → ask or deny
UNKNOWN only when truly unclassifiable (audit logs unmatched tokens)

Compound commands use worst-segment risk.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


ALLOWED_REPO_MARKERS = (
    "sotong24work",
    "sotongwarecontrol",
)

ALLOWED_ABS_ROOTS = (
    r"documents\github\sotong24work",
    r"documents\github\sotongwarecontrol",
    r"documents\sotong24work",
)

SECRET_PATH_RE = re.compile(
    r"(\.env($|\.|[\\/])|\.pem$|id_rsa|credential|service.?account|secrets?[\\/]|keystore)",
    re.I,
)

SAFE_PS_VERBS = {
    "get-childitem",
    "get-content",
    "get-item",
    "get-itemproperty",
    "test-path",
    "select-object",
    "select-string",
    "measure-object",
    "get-filehash",
    "where-object",
    "sort-object",
    "format-table",
    "format-list",
    "out-string",
    "out-null",
    "write-host",
    "write-output",
    "write-verbose",
    "write-warning",
    "write-error",
    "foreach-object",
    "group-object",
    "compare-object",
    "convertto-json",
    "convertfrom-json",
    "join-path",
    "split-path",
    "resolve-path",
    "get-process",
    "get-ciminstance",
    "get-date",
    "get-location",
    "push-location",
    "pop-location",
    "set-location",
    "start-sleep",
}

# HTTP GET/HEAD hosts allowed for verification (read-only).
SAFE_HTTP_HOST_RE = re.compile(
    r"("
    r"sotongware-control\.web\.app|"
    r"localhost|"
    r"127\.0\.0\.1|"
    r"docs\.cursor\.com|"
    r"cursor\.com|"
    r"github\.com|"
    r"raw\.githubusercontent\.com|"
    r"firebase\.google\.com"
    r")",
    re.I,
)

_PERM_RANK = {"allow": 0, "ask": 1, "deny": 2}


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _signal_path() -> Path:
    return Path.home() / "Documents" / "Sotong24Work" / "Logs" / "cursor_approval_state.json"


def _audit_path() -> Path:
    return Path.home() / "Documents" / "Sotong24Work" / "Logs" / "cursor_gate_audit.jsonl"


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
            "state": state,
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


def write_audit(entry: dict) -> None:
    try:
        path = _audit_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except OSError:
        pass


def _reason_ko(category: str, risk: str, permission: str) -> str:
    if permission == "allow":
        return "안전 작업 자동 진행"
    if category == "USER_DEPLOY_APPROVAL" or risk == "PRODUCTION":
        return "운영 배포 승인이 필요해 작업이 안전 정지되었습니다."
    if category == "USER_DESTRUCTIVE" or category == "USER_DESTRUCTIVE_APPROVAL":
        return "파괴적 작업 승인이 필요해 작업이 안전 정지되었습니다."
    if category == "USER_SECRET" or category == "USER_SECRET_APPROVAL":
        return "비밀/자격증명 변경 승인이 필요합니다."
    if category == "USER_PUSH_APPROVAL":
        return "git push 승인이 필요합니다."
    if category == "USER_OUTSIDE_ROOT" or risk == "OUTSIDE_WORKSPACE":
        return "허용 repo 밖 파일 작업 승인이 필요합니다."
    if category == "USER_GOLDEN_RUN" or category == "USER_REVIEW_GATE":
        return "Golden Run / STEP15·STEP18 사용자 검토 gate — 자동 승인 금지"
    if category == "USER_PUBLIC_RELEASE":
        return "외부 공개/스토어 배포 승인이 필요합니다."
    return f"Cursor 승인 대기 ({category}/{risk})"


def _norm(command: str) -> str:
    return (command or "").strip().lower().replace("/", "\\")


def _paths_in_allowed_repos(command: str) -> bool:
    low = _norm(command)
    abs_paths = re.findall(r"[a-z]:\\[^\s\"']+", low)
    if not abs_paths:
        return True
    for p in abs_paths:
        if any(root in p for root in ALLOWED_ABS_ROOTS):
            continue
        if any(m in p for m in ALLOWED_REPO_MARKERS):
            continue
        # TEMP paths used for read/download verification
        if r"\temp\\" in p or p.startswith(r"c:\users\\") and r"\appdata\local\temp" in p:
            continue
        return False
    return True


def _has_secret_path(command: str) -> bool:
    return bool(SECRET_PATH_RE.search(command or ""))


def _split_segments(command: str) -> list[str]:
    text = command or ""
    parts: list[str] = []
    buf: list[str] = []
    quote = ""
    i = 0
    while i < len(text):
        ch = text[i]
        if quote:
            buf.append(ch)
            if ch == quote:
                quote = ""
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            buf.append(ch)
            i += 1
            continue
        if ch in ("\n", ";"):
            seg = "".join(buf).strip()
            if seg:
                parts.append(seg)
            buf = []
            i += 1
            continue
        if text.startswith("&&", i) or text.startswith("||", i):
            seg = "".join(buf).strip()
            if seg:
                parts.append(seg)
            buf = []
            i += 2
            continue
        if ch == "|" and not text.startswith("||", i):
            buf.append(ch)
            i += 1
            continue
        buf.append(ch)
        i += 1
    seg = "".join(buf).strip()
    if seg:
        parts.append(seg)
    return parts or [text.strip()]


def _strip_leading_assignments(seg: str) -> str:
    s = seg.strip().lstrip("&")
    while True:
        m = re.match(r"^(\$[a-z_][\w:-]*\s*=\s*[^;|]+)\s+(.*)$", s, re.I | re.S)
        if not m:
            break
        s = m.group(2).strip()
    return s


def _is_deploy_execution(seg: str) -> bool:
    """True only when deploy script/command is being executed — not mere path checks."""
    low = _norm(seg)
    if re.search(r"\bfirebase\s+deploy\b", low):
        return True
    if re.search(r"\bfirebase\s+use\b", low):
        return True
    # Explicit invocation forms
    if re.search(
        r"("
        r"(-file|-command)\s+[^\n]*deploy_control\.ps1|"
        r"(\\|/|\./|\.\\)?scripts\\deploy_control\.ps1|"
        r"\bpwsh\b[^\n]*deploy_control\.ps1|"
        r"\bpowershell\b[^\n]*deploy_control\.ps1|"
        r"&\s*[^\n]*deploy_control\.ps1"
        r")",
        low,
    ):
        # Exclude Test-Path / Get-Item / Resolve-Path / Get-Content of the script
        if re.search(
            r"\b(test-path|get-item|resolve-path|get-content|select-string|"
            r"get-filehash|get-childitem)\b",
            low,
        ):
            return False
        return True
    return False


def _http_method(seg: str) -> str:
    low = seg.lower()
    if re.search(r"(^|[\s\"'])-method\s+(post|put|patch|delete)\b", low):
        m = re.search(r"-method\s+(post|put|patch|delete)\b", low)
        return (m.group(1) if m else "get").upper()
    if re.search(r"\bcurl\b.*\s-([dF]|X\s*(post|put|patch|delete))\b", low):
        return "POST"
    if re.search(r"\burllib\.request\.(urlopen|Request)\b", low) and re.search(
        r"method\s*=\s*['\"]?(post|put|patch|delete)", low
    ):
        return "POST"
    return "GET"


def _classify_http(seg: str) -> tuple[str, str, str, str] | None:
    low = _norm(seg)
    is_iwr = bool(re.search(r"\b(invoke-webrequest|invoke-restmethod)\b", low))
    is_curl = bool(re.search(r"(^|[;&|]\s*)curl(\.exe)?\b", low))
    is_py_http = bool(
        re.search(r"\b(urllib\.request|requests\.(get|head)|http\.client)\b", low)
    )
    if not (is_iwr or is_curl or is_py_http):
        return None
    method = _http_method(seg)
    if method != "GET" and method != "HEAD":
        return "ask", "USER_DEPLOY_APPROVAL", "PRODUCTION", f"http_{method.lower()}"
    # Allow GET/HEAD; prefer known hosts but also allow generic GET verification
    # of *.web.app / localhost. Mutating production hosts still blocked via method.
    if re.search(r"sotongware\.com|automation\.sotongware\.com", low):
        # Read-only status check of production URLs is allowed; mutation already blocked.
        return "allow", "SAFE_HTTP_READ", "SAFE", "http_get_prod_status"
    return "allow", "SAFE_HTTP_READ", "SAFE", "http_get"


def _classify_git(seg: str) -> tuple[str, str, str, str] | None:
    low = seg.lower()
    stripped = _strip_leading_assignments(seg).lower().strip()
    if not (
        stripped.startswith("git")
        or re.search(r"(^|[;&|]\s*)git\b", low)
        or re.match(r"^git\b", stripped)
    ):
        # pipeline starting with git
        if not re.match(r"^git\b", stripped.split("|")[0].strip()):
            return None

    if re.search(r"\bgit\s+push\b", low):
        if re.search(r"--force|\s-f\b", low):
            return "deny", "USER_DESTRUCTIVE", "DESTRUCTIVE", "force_push"
        return "deny", "USER_PUSH_APPROVAL", "PRODUCTION", "git_push"

    if re.search(r"\bgit\s+reset\b", low):
        return "deny", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_reset"
    if re.search(r"\bgit\s+clean\b", low):
        return "deny", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_clean"
    if re.search(r"\bgit\s+stash\b", low):
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_stash"
    if re.search(r"\bgit\s+(checkout|restore)\b", low):
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_checkout_restore"
    if re.search(r"\bgit\s+worktree\s+remove\b", low):
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_worktree_remove"
    if re.search(r"\bgit\s+rebase\b|\bgit\s+filter(-|\\s)", low):
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_history_rewrite"

    # Broad add that may mix unrelated dirty (-A lowercases to -a)
    if re.search(r"\bgit\s+add\s+(?:--all|-a|\.)(\s|$)", low):
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_add_all"

    read_subs = (
        r"status|diff|log|show|rev-parse|rev-list|branch|fetch|remote|"
        r"ls-files|ls-tree|describe|merge-base|blame|shortlog|tag|"
        r"worktree\s+list|config\s+--get|symbolic-ref|name-rev|"
        r"cat-file|for-each-ref|count-objects|version|help"
    )
    if re.search(rf"\bgit\s+({read_subs})\b", low):
        return "allow", "SAFE_GIT_READ", "SAFE", "git_read"
    # `git -C path status` etc.
    if re.search(rf"\bgit\s+-C\s+\S+\s+({read_subs})\b", low):
        return "allow", "SAFE_GIT_READ", "SAFE", "git_read_c"

    if re.search(r"\bgit\s+add\b", low):
        return "allow", "SAFE_COMMIT", "SAFE", "git_add"
    if re.search(r"\bgit\s+commit\b", low):
        return "allow", "SAFE_COMMIT", "SAFE", "git_commit"
    if re.search(r"\bgit\s+worktree\s+add\b", low):
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_worktree_add"

    return "ask", "UNKNOWN", "UNKNOWN", "git_unclassified"


def _classify_python(seg: str) -> tuple[str, str, str, str] | None:
    low = _norm(seg)
    stripped = _strip_leading_assignments(seg)
    if not re.match(r"^(python3?|py)\b", stripped.strip(), re.I):
        return None

    # Dangerous execution tokens inside python
    if _is_deploy_execution(seg):
        return "ask", "USER_DEPLOY_APPROVAL", "PRODUCTION", "python_deploy"
    if re.search(r"\bgit\s+push\b|remove-item|\brm\s+-[a-z]*r|firebase\s+deploy", low):
        return "ask", "USER_DEPLOY_APPROVAL", "PRODUCTION", "python_dangerous_token"
    if re.search(r"start_job|wi_plan_1788707699582|step\s*18|step\s*15", low):
        return "deny", "USER_GOLDEN_RUN", "PRODUCTION", "golden_or_gate"

    http = _classify_http(seg)
    if http and ("urllib" in low or "requests" in low or "http.client" in low):
        return http

    if re.search(r"\b(-m\s+pytest|pytest)\b", low):
        return "allow", "SAFE_TEST", "SAFE", "pytest"

    # Trusted helpers
    if re.search(r"\bscripts\\cursor_safe\\[^\s]+\.py\b", low):
        return "allow", "SAFE_VALIDATION", "SAFE", "cursor_safe_helper"
    if re.search(r"\bscripts\\(test_|verify_)[^\s]+\.py\b", low):
        return "allow", "SAFE_TEST", "SAFE", "python_test_or_verify"
    if re.search(r"\bscripts\\[^\s]+\.py\b", low):
        return "allow", "SAFE_VALIDATION", "SAFE", "python_repo_script"
    if re.search(r"\btest_[^\s]+\.py\b", low):
        return "allow", "SAFE_TEST", "SAFE", "python_test_file"

    # Inline -c: allow only when clearly non-mutating (no file write APIs / no http write)
    if re.search(r"\b-[cm]\b", low) or " -c " in f" {low} ":
        if re.search(
            r"(open\([^)]*['\"]w|path\.write|write_text|write_bytes|"
            r"unlink|rmtree|shutil\.move|subprocess.*(push|deploy|remove))",
            low,
        ):
            return "ask", "UNKNOWN", "UNKNOWN", "python_inline_mutative"
        return "allow", "SAFE_VALIDATION", "SAFE", "python_inline_readonly"

    if re.search(r"\.py\b", low):
        if _paths_in_allowed_repos(seg):
            return "allow", "SAFE_VALIDATION", "SAFE", "python_file_in_repo"
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "python_outside_repo"

    return "allow", "SAFE_VALIDATION", "SAFE", "python_generic_safe"


def _is_readonly_powershell(seg: str) -> bool:
    low = _norm(seg)
    if _is_deploy_execution(seg):
        return False
    if re.search(r"\b(remove-item|rmdir|del\s+/|set-content|add-content|setx|reg\s+add)\b", low):
        return False
    if re.search(r"\b(invoke-webrequest|invoke-restmethod)\b", low):
        return False  # handled by http classifier
    tokens = re.findall(r"\b[a-z]+-[a-z]+\b", low)
    if not tokens:
        return False
    for t in tokens:
        if t not in SAFE_PS_VERBS:
            return False
    return True


def _classify_segment(seg: str) -> tuple[str, str, str, str]:
    text = (seg or "").strip()
    if not text or text.startswith("#"):
        return "allow", "SAFE_READ", "SAFE", "comment_or_empty"

    low = _norm(text)
    stripped = _strip_leading_assignments(text)
    stripped_low = _norm(stripped)

    # Golden / review gates
    if re.search(r"wi_plan_1788707699582|\bstart_job\b", low):
        return "deny", "USER_GOLDEN_RUN", "PRODUCTION", "golden_or_start_job"
    if re.search(r"step\s*18|site_publish|public\s+release|store\s+publish", low):
        return "deny", "USER_PUBLIC_RELEASE", "PRODUCTION", "public_release"
    if re.search(r"step\s*15|site_user_review|design_change_requested", low):
        return "deny", "USER_REVIEW_GATE", "PRODUCTION", "step15_gate"

    if _is_deploy_execution(text):
        return "deny", "USER_DEPLOY_APPROVAL", "PRODUCTION", "deploy_execution"

    if re.search(r"\b(remove-item|rmdir\s+/s|\brm\s+-[a-z]*r|\bdel\s+/[sf])\b", low):
        return "deny", "USER_DESTRUCTIVE", "DESTRUCTIVE", "destructive_delete"

    if _has_secret_path(text) and re.search(
        r"\b(set-content|add-content|out-file|copy-item|move-item|new-item|>\s*)\b",
        low,
    ):
        return "ask", "USER_SECRET", "SECRET", "secret_path_write"

    if _has_secret_path(text) and re.search(r"\b(get-content|type|cat)\b", low):
        return "ask", "USER_SECRET", "SECRET", "secret_path_read"

    git = _classify_git(text)
    if git:
        return git

    http = _classify_http(text)
    if http:
        return http

    py = _classify_python(text)
    if py:
        return py

    # Copy/move/rename/new-item
    if re.search(r"\b(copy-item|move-item|rename-item|new-item)\b", low):
        if re.search(r"sotongwareweb", low):
            return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "web_write"
        if not _paths_in_allowed_repos(text):
            return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "copy_outside"
        return "allow", "SAFE_COPY", "SAFE", "safe_repo_copy"

    # Trusted PowerShell helpers under scripts/cursor_safe
    if re.search(r"scripts\\cursor_safe\\[^\s]+\.ps1\b", low):
        if _is_deploy_execution(text):
            return "deny", "USER_DEPLOY_APPROVAL", "PRODUCTION", "deploy_execution"
        return "allow", "SAFE_VALIDATION", "SAFE", "cursor_safe_ps1"

    # Flutter / dart / npm / node
    build_safe = [
        (r"^(flutter\s+(analyze|test|pub\s+get|build|config|doctor|devices)\b)", "SAFE_TEST"),
        (r"^(dart\s+(analyze|test|format|pub)\b)", "SAFE_TEST"),
        (r"^(npm\s+(test|run\s+(test|lint|build|typecheck)|ci|install)\b)", "SAFE_TEST"),
        (r"^(npx\s+\S+)", "SAFE_TEST"),
        (r"^(pytest\b)", "SAFE_TEST"),
        (r"^(cmake\b|ctest\b|msbuild\b|dotnet\b)", "SAFE_BUILD"),
        (r"^(rg\b|dir\b|ls\b|where(\.exe)?\b|type\b|cat\b|echo\b|findstr\b)", "SAFE_READ"),
    ]
    for pat, category in build_safe:
        if re.search(pat, stripped_low.strip()):
            return "allow", category, "SAFE", "safe_dev_command"

    if _is_readonly_powershell(text):
        return "allow", "SAFE_READ", "SAFE", "powershell_readonly"

    if re.match(r"^(cd|set-location|push-location|pop-location)\b", stripped_low.strip()):
        return "allow", "SAFE_READ", "SAFE", "location_change"

    if re.match(r"^\$[a-z_][\w]*\s*=", stripped_low.strip()):
        return "allow", "SAFE_OUTPUT", "SAFE", "ps_assignment"

    # powershell -NoProfile -Command "..." — unwrap
    m = re.match(
        r"^(powershell|pwsh)(\.exe)?\b.*(-(command|c)|/c)\s+(.+)$",
        stripped,
        re.I | re.S,
    )
    if m:
        inner = m.group(5).strip().strip("'\"")
        return _classify_segment(inner)

    unmatched = re.findall(r"[A-Za-z][\w.-]+", stripped)[:12]
    return (
        "ask",
        "UNKNOWN",
        "UNKNOWN",
        "manual_review:" + ",".join(unmatched[:6]),
    )


def classify(command: str) -> tuple[str, str, str, str]:
    text = (command or "").strip()
    if not text:
        return "allow", "SAFE_READ", "SAFE", "empty"

    low = _norm(text)
    # Whole-command hard checks — execution only
    if re.search(r"\bgit\s+push\b", low):
        return "deny", "USER_PUSH_APPROVAL", "PRODUCTION", "git_push_compound"
    if _is_deploy_execution(text):
        return "deny", "USER_DEPLOY_APPROVAL", "PRODUCTION", "deploy_compound"
    if re.search(r"\b(remove-item|rmdir\s+/s|\brm\s+-[a-z]*r)\b", low):
        return "deny", "USER_DESTRUCTIVE", "DESTRUCTIVE", "delete_compound"

    best = ("allow", "SAFE_READ", "SAFE", "default")
    for seg in _split_segments(text):
        perm, category, risk, reason = _classify_segment(seg)
        if _PERM_RANK[perm] > _PERM_RANK[best[0]]:
            best = (perm, category, risk, reason)
        elif _PERM_RANK[perm] == _PERM_RANK[best[0]]:
            # Same severity: keep latest concrete classification (compound chains).
            best = (perm, category, risk, reason)
    return best


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = {}
    command = str(payload.get("command") or "")
    permission, category, risk, reason = classify(command)

    segments = _split_segments(command)
    write_audit(
        {
            "ts": _now_iso(),
            "hook": "shell_gate",
            "command": command[:1000],
            "permission": permission,
            "category": category,
            "risk": risk,
            "reason": reason,
            "segments": [s[:200] for s in segments[:20]],
            "unmatched": reason if category == "UNKNOWN" else "",
            "policySource": "Sotong24Work/.cursor/hooks/shell_gate.py",
            "policyVersion": "phase4-final",
        }
    )

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
            f"Blocked: {reason}. Destructive/deploy/secret/STEP gate requires manual approval."
        )
    elif permission == "ask":
        out["user_message"] = _reason_ko(category, risk, permission)
    print(json.dumps(out, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
