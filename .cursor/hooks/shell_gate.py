#!/usr/bin/env python3
"""Deterministic shell gate — Unattended Ops Phase 4.2 (real-world SAFE matrix).

Phase 4.1 security kept fail-closed. Phase 4.2 adds only log-proven SAFE gaps:
Get-NetTCPConnection, full-path MSBuild.exe, controlled Sotong24Work process restart.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


POLICY_VERSION = "phase4.2-realworld"

ALLOWED_ROOT_NAMES = (
    "Sotong24Work",
    "SotongwareControl",
)

SECRET_PATH_RE = re.compile(
    r"(\.env($|\.|[\\/])|\.pem$|id_rsa|credential|service.?account|secrets?[\\/]|keystore)",
    re.I,
)

GOLDEN_PATH_RE = re.compile(
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
    r"current_work\.json|"
    r"\bstart_job\b|"
    r"site_publish|public[_\s-]?release|store[_\s-]?publish"
    r")",
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
    "get-nettcpconnection",
    "get-netudpendpoint",
    "get-ciminstance",
    "get-date",
    "get-location",
    "push-location",
    "pop-location",
    "set-location",
    "start-sleep",
}

SAFE_HTTP_HOST_RE = re.compile(
    r"("
    r"sotongware-control\.web\.app|"
    r"localhost|"
    r"127\.0\.0\.1|"
    r"docs\.cursor\.com|"
    r"cursor\.com|"
    r"github\.com|"
    r"raw\.githubusercontent\.com|"
    r"firebase\.google\.com|"
    r"sotongware\.com"
    r")",
    re.I,
)

HTTP_WRITE_FLAG_RE = re.compile(
    r"("
    r"-X\s*(POST|PUT|PATCH|DELETE)\b|"
    r"--request\s+(POST|PUT|PATCH|DELETE)\b|"
    r"--data(-raw|-binary|-urlencode)?\b|"
    r"(^|[\s\"'])-d([\s\"'=]|$)|"
    r"(^|[\s\"'])-F([\s\"'=]|$)|"
    r"--form\b|"
    r"--upload-file\b|"
    r"(^|[\s\"'])-T([\s\"'=]|$)|"
    r"-Method\s+(POST|PUT|PATCH|DELETE)\b|"
    r"requests\.(post|put|patch|delete)\b|"
    r"urllib\.request\.(urlopen|Request)\b|"
    r"http\.client\."
    r")",
    re.I,
)

WRITE_CMDLET_RE = re.compile(
    r"\b(set-content|add-content|out-file|tee-object)\b",
    re.I,
)

_PERM_RANK = {"allow": 0, "ask": 1, "deny": 2}
_CAT_RANK = {
    "USER_SECRET": 100,
    "USER_GOLDEN_RUN": 95,
    "USER_PUBLIC_RELEASE": 94,
    "USER_REVIEW_GATE": 93,
    "USER_DEPLOY_APPROVAL": 90,
    "USER_HTTP_WRITE": 88,
    "USER_PUSH_APPROVAL": 85,
    "USER_DESTRUCTIVE": 80,
    "USER_OUTSIDE_ROOT": 70,
    "USER_INLINE_PYTHON": 60,
    "UNKNOWN": 50,
}


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
    if category in ("USER_DEPLOY_APPROVAL",) or risk == "PRODUCTION":
        return "운영 배포 승인이 필요해 작업이 안전 정지되었습니다."
    if category == "USER_HTTP_WRITE":
        return "HTTP 쓰기(POST/PUT/PATCH/DELETE) 승인이 필요합니다."
    if category in ("USER_DESTRUCTIVE", "USER_DESTRUCTIVE_APPROVAL"):
        return "파괴적 작업 승인이 필요해 작업이 안전 정지되었습니다."
    if category in ("USER_SECRET", "USER_SECRET_APPROVAL"):
        return "비밀/자격증명 변경 승인이 필요합니다."
    if category == "USER_PUSH_APPROVAL":
        return "git push 승인이 필요합니다."
    if category == "USER_OUTSIDE_ROOT" or risk == "OUTSIDE_WORKSPACE":
        return "허용 repo 밖 파일 작업 승인이 필요합니다."
    if category in ("USER_GOLDEN_RUN", "USER_REVIEW_GATE"):
        return "Golden Run / STEP15·STEP18 사용자 검토 gate — 자동 승인 금지"
    if category == "USER_PUBLIC_RELEASE":
        return "외부 공개/스토어 배포 승인이 필요합니다."
    if category == "USER_INLINE_PYTHON":
        return "임의 Python(-c/-m/비신뢰 스크립트) 실행 승인이 필요합니다."
    return f"Cursor 승인 대기 ({category}/{risk})"


def _norm(command: str) -> str:
    return (command or "").strip().lower().replace("/", "\\")


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


def _resolve_path(raw: str, *, base: Path | None = None) -> Path | None:
    text = (raw or "").strip().strip("'\"")
    if not text:
        return None
    try:
        p = Path(text)
        if not p.is_absolute():
            p = (base or Path.cwd()) / p
        return p.resolve()
    except (OSError, RuntimeError, ValueError):
        return None


def _is_under_allowed_root(path: Path | None) -> bool:
    if path is None:
        return False
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


def _path_from_text(token: str) -> Path | None:
    return _resolve_path(token)


def _extract_path_tokens(text: str) -> list[str]:
    found: list[str] = []
    for m in re.finditer(r'"([^"]+)"|\'([^\']+)\'|([a-zA-Z]:\\[^\s|&;<>]+)|((?:\.\.?[\\/]|[\\/])?[^\s|&;<>\"]+\.[A-Za-z0-9_]+)', text or ""):
        tok = m.group(1) or m.group(2) or m.group(3) or m.group(4) or ""
        tok = tok.strip()
        if tok and tok not in found:
            found.append(tok)
    return found


def _classify_target_path(path_hint: str) -> tuple[str, str, str, str] | None:
    raw = (path_hint or "").strip().strip("'\"")
    if not raw:
        return "ask", "UNKNOWN", "UNKNOWN", "empty_write_target"
    low = raw.lower().replace("/", "\\")
    if SECRET_PATH_RE.search(low) or SECRET_PATH_RE.search(raw):
        return "ask", "USER_SECRET", "SECRET", "secret_path_write"
    if GOLDEN_PATH_RE.search(low) or GOLDEN_PATH_RE.search(raw):
        return "ask", "USER_GOLDEN_RUN", "PRODUCTION", "golden_or_wi_write"
    if "sotongwareweb" in low:
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "web_write"
    resolved = _path_from_text(raw)
    if resolved is None:
        # Relative ordinary file without traversal → treat as in-repo edit candidate
        if ".." in Path(raw).parts:
            return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "traversal"
        if re.match(r"^[a-zA-Z]:\\", raw):
            return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "unresolved_abs"
        return "allow", "SAFE_EDIT", "SAFE", "relative_repo_write"
    if not _is_under_allowed_root(resolved):
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "outside_root"
    low_res = str(resolved).lower().replace("/", "\\")
    if SECRET_PATH_RE.search(low_res):
        return "ask", "USER_SECRET", "SECRET", "secret_path_write"
    if GOLDEN_PATH_RE.search(low_res):
        return "ask", "USER_GOLDEN_RUN", "PRODUCTION", "golden_or_wi_write"
    return "allow", "SAFE_EDIT", "SAFE", "allowed_repo_write"


def _has_secret_path(command: str) -> bool:
    return bool(SECRET_PATH_RE.search(command or ""))


def _split_segments(command: str) -> list[str]:
    """Split on ; | && || while respecting quotes. Keep redirect inside segment."""
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
            seg = "".join(buf).strip()
            if seg:
                parts.append(seg)
            buf = []
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


def _redirect_targets(seg: str) -> list[str]:
    """Extract filesystem targets of >, >>, 2>, 2>> (ignore 2>&1)."""
    targets: list[str] = []
    for m in re.finditer(
        r"(?<![>\d])(?:\d)?>>?\s*(?!&\d)(?P<q>[\"'])(?P<a>.*?)(?P=q)|"
        r"(?<![>\d])(?:\d)?>>?\s*(?!&\d)(?P<b>[^\s|&;]+)",
        seg or "",
    ):
        t = m.group("a") or m.group("b") or ""
        t = t.strip()
        if t and t not in ("&1", "&2"):
            targets.append(t)
    return targets


def _write_cmdlet_targets(seg: str) -> list[str]:
    low = seg or ""
    if not WRITE_CMDLET_RE.search(low):
        return []
    targets: list[str] = []
    for m in re.finditer(
        r"\b(?:set-content|add-content|out-file|tee-object)\b"
        r"(?:\s+-\w+\s+[^\s]+)*\s+"
        r"(?:-path\s+|-\w+:)?(?P<q>[\"'])(?P<a>.*?)(?P=q)|"
        r"\b(?:set-content|add-content|out-file|tee-object)\b"
        r"(?:\s+-\w+\s+[^\s]+)*\s+"
        r"(?:-path\s+)?(?P<b>[^\s\-\"'][^\s]*)",
        low,
        re.I,
    ):
        t = (m.group("a") or m.group("b") or "").strip()
        if t and not t.startswith("-"):
            targets.append(t)
    # Set-Content -Path x / -LiteralPath
    for m in re.finditer(
        r"-(?:path|literalpath)\s+(?P<q>[\"'])(?P<a>.*?)(?P=q)|"
        r"-(?:path|literalpath)\s+(?P<b>[^\s]+)",
        low,
        re.I,
    ):
        t = (m.group("a") or m.group("b") or "").strip()
        if t:
            targets.append(t)
    return targets


def _is_deploy_execution(seg: str) -> bool:
    low = _norm(seg)
    if re.search(r"\bfirebase\s+deploy\b", low):
        return True
    if re.search(r"\bfirebase\s+use\b", low):
        return True
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
        if re.search(
            r"\b(test-path|get-item|resolve-path|get-content|select-string|"
            r"get-filehash|get-childitem)\b",
            low,
        ):
            return False
        return True
    return False


def _http_is_write(seg: str) -> bool:
    low = seg or ""
    if HTTP_WRITE_FLAG_RE.search(low):
        # urllib/http.client without explicit write method may still be GET — require write markers
        if re.search(r"\b(urllib\.request|http\.client)\b", low, re.I):
            if re.search(
                r"method\s*=\s*['\"]?(post|put|patch|delete)|requests\.(post|put|patch|delete)|--data|\b-d\b|\b-X\s",
                low,
                re.I,
            ):
                return True
            return False
        return True
    if re.search(r"\b(invoke-webrequest|invoke-restmethod)\b", low, re.I):
        if re.search(r"-method\s+(post|put|patch|delete)\b", low, re.I):
            return True
        if re.search(r"\s-body\s|\s-infile\s|\s-form\s", low, re.I):
            return True
        return False
    return False


def _classify_http(seg: str) -> tuple[str, str, str, str] | None:
    low = _norm(seg)
    is_iwr = bool(re.search(r"\b(invoke-webrequest|invoke-restmethod)\b", low))
    is_curl = bool(re.search(r"(^|[;&|\s])curl(\.exe)?\b", low) or re.match(r"^curl(\.exe)?\b", low))
    is_py_http = bool(
        re.search(
            r"\b(urllib\.request|requests\.(get|head|post|put|patch|delete)|http\.client)\b",
            low,
        )
    )
    if not (is_iwr or is_curl or is_py_http):
        return None
    if _http_is_write(seg):
        return "ask", "USER_HTTP_WRITE", "PRODUCTION", "http_write"
    # GET/HEAD only
    if is_curl and not re.search(r"\s-[iI]\b|\s--head\b|\s-X\s*GET\b|--request\s+GET\b|^curl(\.exe)?\s+[^-]", seg, re.I):
        # bare curl URL is typically GET — allow if host ok or generic GET verification
        pass
    host_ok = bool(SAFE_HTTP_HOST_RE.search(seg)) or bool(
        re.search(r"https?://", seg, re.I)
    )
    if not host_ok and is_iwr:
        return "ask", "UNKNOWN", "UNKNOWN", "http_host_unclear"
    return "allow", "SAFE_HTTP_READ", "SAFE", "http_get"


def _git_c_path(seg: str) -> str | None:
    m = re.search(
        r"\bgit\s+-c\s+(?P<q>[\"'])(?P<a>.*?)(?P=q)|\bgit\s+-c\s+(?P<b>\S+)",
        seg or "",
        re.I,
    )
    if not m:
        return None
    return (m.group("a") or m.group("b") or "").strip()


def _classify_git(seg: str) -> tuple[str, str, str, str] | None:
    low = seg.lower()
    stripped = _strip_leading_assignments(seg).lower().strip()
    if not (
        stripped.startswith("git")
        or re.search(r"(^|[;&|\s])git\b", low)
        or re.match(r"^git\b", stripped)
    ):
        if not re.match(r"^git\b", stripped.split("|")[0].strip()):
            return None

    c_path = _git_c_path(seg)
    if c_path is not None:
        resolved = _path_from_text(c_path)
        if resolved is None or not _is_under_allowed_root(resolved):
            return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "git_c_outside"

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
    if re.search(r"\bgit\s+rebase\b|\bgit\s+filter(-|\s)", low):
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_history_rewrite"

    if re.search(r"\bgit\s+add\s+(?:--all|-a|\.)(\s|$)", low):
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_add_all"

    read_subs = (
        r"status|diff|log|show|rev-parse|rev-list|branch|fetch|remote|"
        r"ls-files|ls-tree|describe|merge-base|blame|shortlog|tag|"
        r"worktree\s+list|config\s+--get|symbolic-ref|name-rev|"
        r"cat-file|for-each-ref|count-objects|version|help"
    )
    # Note: `low` is lowercased, so match `-c` (from git -C).
    if re.search(
        rf"\bgit(?:\s+-c\s+(?:\"[^\"]+\"|'[^']+'|\S+))?\s+({read_subs})\b",
        low,
    ):
        return "allow", "SAFE_GIT_READ", "SAFE", "git_read"

    if re.search(r"\bgit\s+add\b", low):
        return "allow", "SAFE_COMMIT", "SAFE", "git_add"
    if re.search(r"\bgit\s+commit\b", low):
        return "allow", "SAFE_COMMIT", "SAFE", "git_commit"
    if re.search(r"\bgit\s+worktree\s+add\b", low):
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "git_worktree_add"

    return "ask", "UNKNOWN", "UNKNOWN", "git_unclassified"


def _trusted_python_script(seg: str) -> tuple[str, str, str, str] | None:
    """Allow only cursor_safe helpers and scripts/test_*.py / verify_*.py / test_unattended_ops_*.py."""
    m = re.search(
        r"(?P<script>(?:[a-zA-Z]:\\[^\s\"']+|[\w.\\/-]+)\.py)\b",
        seg or "",
        re.I,
    )
    if not m:
        return None
    script_tok = m.group("script").replace("/", "\\")
    low = script_tok.lower()

    resolved = _path_from_text(script_tok)
    # Relative scripts/... under cwd / allowed roots
    if resolved is None:
        for root in _allowed_roots():
            cand = _resolve_path(script_tok, base=root)
            if cand is not None and cand.exists():
                resolved = cand
                break
        if resolved is None:
            # Still classify by relative pattern if clearly under scripts/
            if "scripts\\cursor_safe\\" in low and low.endswith(".py"):
                return "allow", "SAFE_VALIDATION", "SAFE", "cursor_safe_helper"
            if re.search(r"scripts\\test_unattended_ops_[^\s\\/]+\.py$", low):
                return "allow", "SAFE_TEST", "SAFE", "unattended_ops_test"
            if re.search(r"scripts\\(test_|verify_)[^\s\\/]+\.py$", low):
                return "allow", "SAFE_TEST", "SAFE", "python_test_or_verify"
            return "ask", "USER_INLINE_PYTHON", "UNKNOWN", "python_script_unresolved"

    if not _is_under_allowed_root(resolved):
        return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "python_outside_root"

    rel = str(resolved).lower().replace("/", "\\")
    if "\\scripts\\cursor_safe\\" in rel and rel.endswith(".py"):
        return "allow", "SAFE_VALIDATION", "SAFE", "cursor_safe_helper"
    if re.search(r"\\scripts\\test_unattended_ops_[^\\]+\.py$", rel):
        return "allow", "SAFE_TEST", "SAFE", "unattended_ops_test"
    if re.search(r"\\scripts\\(test_|verify_)[^\\]+\.py$", rel):
        return "allow", "SAFE_TEST", "SAFE", "python_test_or_verify"
    # Any other .py — not auto-allowed
    return "ask", "USER_INLINE_PYTHON", "UNKNOWN", "python_untrusted_script"


def _classify_python(seg: str) -> tuple[str, str, str, str] | None:
    stripped = _strip_leading_assignments(seg)
    if not re.match(r"^(python3?|py)\b", stripped.strip(), re.I):
        return None
    low = _norm(seg)

    if _is_deploy_execution(seg):
        return "ask", "USER_DEPLOY_APPROVAL", "PRODUCTION", "python_deploy"
    if re.search(r"\bgit\s+push\b|remove-item|\brm\s+-[a-z]*r|firebase\s+deploy", low):
        return "ask", "USER_DEPLOY_APPROVAL", "PRODUCTION", "python_dangerous_token"
    if re.search(r"start_job|wi_plan_1788707699582|step\s*18|step\s*15", low):
        return "deny", "USER_GOLDEN_RUN", "PRODUCTION", "golden_or_gate"

    if _http_is_write(seg) or re.search(r"requests\.(post|put|patch|delete)\b", low):
        return "ask", "USER_HTTP_WRITE", "PRODUCTION", "python_http_write"

    if re.search(
        r"(open\([^)]*['\"][wa]|path\.write|write_text|write_bytes|"
        r"unlink|rmtree|shutil\.(move|rmtree)|os\.remove)",
        low,
    ):
        if _has_secret_path(seg) or ".env" in low:
            return "ask", "USER_SECRET", "SECRET", "python_secret_write"
        if GOLDEN_PATH_RE.search(seg):
            return "ask", "USER_GOLDEN_RUN", "PRODUCTION", "python_golden_write"
        return "ask", "USER_INLINE_PYTHON", "UNKNOWN", "python_inline_mutative"

    # -c / -m arbitrary → ask (unless proven read-only AND no network write — still ask per 4.1)
    if re.search(r"(^|\s)-c(\s|$)|(^|\s)-m(\s|$)", f" {stripped} ", re.I):
        return "ask", "USER_INLINE_PYTHON", "UNKNOWN", "python_inline_c_or_m"

    if re.search(r"\b(-m\s+pytest|pytest)\b", low):
        return "allow", "SAFE_TEST", "SAFE", "pytest"

    trusted = _trusted_python_script(seg)
    if trusted:
        return trusted

    if re.search(r"\.py\b", low):
        return "ask", "USER_INLINE_PYTHON", "UNKNOWN", "python_untrusted_script"

    return "ask", "USER_INLINE_PYTHON", "UNKNOWN", "python_generic_ask"


def _is_readonly_powershell(seg: str) -> bool:
    low = _norm(seg)
    if _is_deploy_execution(seg):
        return False
    if WRITE_CMDLET_RE.search(low):
        return False
    if re.search(r"\b(remove-item|rmdir|del\s+/|setx|reg\s+add)\b", low):
        return False
    if re.search(r"(?<![>\d])>{1,2}", seg or ""):
        return False
    if re.search(r"\b(invoke-webrequest|invoke-restmethod)\b", low):
        return False
    tokens = re.findall(r"\b[a-z]+-[a-z]+\b", low)
    if not tokens:
        return False
    for t in tokens:
        if t not in SAFE_PS_VERBS:
            return False
    return True


def _worse(
    a: tuple[str, str, str, str],
    b: tuple[str, str, str, str],
) -> tuple[str, str, str, str]:
    if _PERM_RANK[b[0]] > _PERM_RANK[a[0]]:
        return b
    if _PERM_RANK[b[0]] < _PERM_RANK[a[0]]:
        return a
    if _CAT_RANK.get(b[1], 0) >= _CAT_RANK.get(a[1], 0):
        return b
    return a


def _classify_segment(seg: str) -> tuple[str, str, str, str]:
    text = (seg or "").strip()
    if not text or text.startswith("#"):
        return "allow", "SAFE_READ", "SAFE", "comment_or_empty"

    low = _norm(text)
    stripped = _strip_leading_assignments(text)
    stripped_low = _norm(stripped)

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

    # Redirect / write cmdlets — evaluate targets (worst wins)
    best: tuple[str, str, str, str] | None = None
    for tgt in _redirect_targets(text) + _write_cmdlet_targets(text):
        cls = _classify_target_path(tgt)
        if cls:
            best = cls if best is None else _worse(best, cls)
    if best is not None:
        return best

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

    if re.search(r"\b(copy-item|move-item|rename-item|new-item)\b", low):
        if "sotongwareweb" in low:
            return "ask", "USER_OUTSIDE_ROOT", "OUTSIDE_WORKSPACE", "web_write"
        toks = _extract_path_tokens(text)
        for tok in toks:
            if re.match(r"^[a-zA-Z]:\\", tok) or "\\" in tok or "/" in tok:
                cls = _classify_target_path(tok)
                if cls and cls[0] != "allow":
                    return cls
        # relative in-repo copy
        return "allow", "SAFE_COPY", "SAFE", "safe_repo_copy"

    if re.search(r"scripts\\cursor_safe\\[^\s]+\.ps1\b", low):
        if _is_deploy_execution(text):
            return "deny", "USER_DEPLOY_APPROVAL", "PRODUCTION", "deploy_execution"
        return "allow", "SAFE_VALIDATION", "SAFE", "cursor_safe_ps1"

    build_safe = [
        (r"^(flutter\s+(analyze|test|pub\s+get|build|config|doctor|devices)\b)", "SAFE_TEST"),
        (r"^(dart\s+(analyze|test|format|pub)\b)", "SAFE_TEST"),
        (r"^(npm\s+(test|run\s+(test|lint|build|typecheck)|ci|install)\b)", "SAFE_TEST"),
        (r"^(npx\s+\S+)", "SAFE_TEST"),
        (r"^(pytest\b)", "SAFE_TEST"),
        # Bare msbuild / dotnet / cmake
        (r"^(cmake\b|ctest\b|msbuild(\.exe)?\b|dotnet\b)", "SAFE_BUILD"),
        # Full-path MSBuild.exe (VS install) with optional PowerShell call operator
        (r"^(&\s*)?(\"[^\"]*\\msbuild\.exe\"|'[^']*\\msbuild\.exe'|[a-z]:\\[^\s\"']*\\msbuild\.exe)(\s|$)", "SAFE_BUILD"),
        (r"^(rg\b|dir\b|ls\b|where(\.exe)?\b|type\b|cat\b|findstr\b)", "SAFE_READ"),
        # echo without redirect already handled; bare echo is SAFE_READ
        (r"^echo\b", "SAFE_READ"),
    ]
    for pat, category in build_safe:
        if re.search(pat, stripped_low.strip()):
            return "allow", category, "SAFE", "safe_dev_command"

    # Controlled local Work process restart (log-proven SAFE during Release verify).
    # Only Sotong24Work_1st by name — never broad Stop-Process / taskkill.
    if re.search(r"\bstop-process\b", stripped_low):
        if re.search(r"-name\s+['\"]?sotong24work(_1st)?['\"]?\b", stripped_low) and not re.search(
            r"\b(remove-item|rmdir|\brm\s+|firebase|git\s+push)\b", stripped_low
        ):
            return "allow", "SAFE_PROC", "SAFE", "work_process_stop"
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "stop_process_unscoped"
    if re.search(r"\bstart-process\b", stripped_low):
        if "sotong24work_1st.exe" in stripped_low.replace("/", "\\"):
            toks = _extract_path_tokens(text)
            for tok in toks:
                if tok.lower().endswith("sotong24work_1st.exe"):
                    cls = _classify_target_path(tok)
                    if cls and cls[0] == "allow":
                        return "allow", "SAFE_PROC", "SAFE", "work_process_start"
                    if cls:
                        return cls
            # relative / bare exe name under Release cwd
            if re.search(r"sotong24work_1st\.exe", stripped_low):
                return "allow", "SAFE_PROC", "SAFE", "work_process_start_rel"
        return "ask", "USER_DESTRUCTIVE", "DESTRUCTIVE", "start_process_unscoped"

    if _is_readonly_powershell(text):
        return "allow", "SAFE_READ", "SAFE", "powershell_readonly"

    if re.match(r"^(cd|set-location|push-location|pop-location)\b", stripped_low.strip()):
        return "allow", "SAFE_READ", "SAFE", "location_change"

    if re.match(r"^\$[a-z_][\w]*\s*=", stripped_low.strip()):
        return "allow", "SAFE_OUTPUT", "SAFE", "ps_assignment"

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
    if re.search(r"\bgit\s+push\b", low):
        return "deny", "USER_PUSH_APPROVAL", "PRODUCTION", "git_push_compound"
    if _is_deploy_execution(text):
        return "deny", "USER_DEPLOY_APPROVAL", "PRODUCTION", "deploy_compound"
    if re.search(r"\b(remove-item|rmdir\s+/s|\brm\s+-[a-z]*r)\b", low):
        return "deny", "USER_DESTRUCTIVE", "DESTRUCTIVE", "delete_compound"

    best = ("allow", "SAFE_READ", "SAFE", "default")
    for seg in _split_segments(text):
        best = _worse(best, _classify_segment(seg))
    return best


def _fail_closed(reason: str) -> int:
    out = {
        "permission": "ask",
        "agent_message": f"shell_gate:ask:UNKNOWN:{reason}",
        "user_message": "Hook fail-closed: 불확실한 shell 명령은 자동 실행하지 않습니다.",
    }
    write_audit(
        {
            "ts": _now_iso(),
            "hook": "shell_gate",
            "command": "",
            "permission": "ask",
            "category": "UNKNOWN",
            "risk": "UNKNOWN",
            "reason": reason,
            "policySource": "Sotong24Work/.cursor/hooks/shell_gate.py",
            "policyVersion": POLICY_VERSION,
            "failClosed": True,
        }
    )
    write_approval_signal(
        state="cursor_waiting_approval",
        category="UNKNOWN",
        summary=reason,
        risk="UNKNOWN",
        permission="ask",
    )
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
                "policyVersion": POLICY_VERSION,
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
    except Exception as exc:  # noqa: BLE001 — fail-closed
        return _fail_closed(f"exception:{type(exc).__name__}")


if __name__ == "__main__":
    raise SystemExit(main())
