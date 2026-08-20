"use strict";

/** Agent Codex telemetry status values (Sotong24Work contract). */
const CODEX_STATUS = new Set([
  "ok",
  "auth_required",
  "app_server_unavailable",
  "unsupported",
  "timeout",
  "parse_error",
]);
const CURSOR_STATUS = new Set(["unknown", "manual", "ok"]);

const SECRET_KEY_RE =
  /(?:token|secret|apikey|api_key|password|credential|authorization|cookie|email)/i;

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

function hasSecretKey(key) {
  return SECRET_KEY_RE.test(String(key));
}

function parseIsoOptional(value) {
  if (value === undefined || value === null || value === "") return undefined;
  const s = String(value).trim();
  if (!s || Number.isNaN(Date.parse(s))) return undefined;
  return s.slice(0, 40);
}

function parsePercent(value) {
  if (value === undefined || value === null || value === "") return undefined;
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return undefined;
  if (n < 0 || n > 100) return undefined;
  return n;
}

function parsePositiveInt(value) {
  if (value === undefined || value === null || value === "") return undefined;
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n) || !Number.isInteger(n) || n < 1) return undefined;
  return n;
}

/**
 * Allowlisted aiUsage.codex for agent heartbeat.
 * Malformed or secret-bearing payloads return undefined (heartbeat still succeeds).
 */
function pickAiUsageCodex(body) {
  if (!isPlainObject(body)) return undefined;
  const aiUsage = body.aiUsage;
  if (!isPlainObject(aiUsage)) return undefined;
  const codex = aiUsage.codex;
  if (!isPlainObject(codex)) return undefined;

  for (const key of Object.keys(codex)) {
    if (hasSecretKey(key)) {
      // Secret-bearing keys are dropped; allowlisted siblings may still persist.
      continue;
    }
  }

  const weeklyRaw = codex.weekly;
  if (weeklyRaw !== undefined && weeklyRaw !== null && !isPlainObject(weeklyRaw)) {
    return undefined;
  }

  const out = {};

  if (codex.status !== undefined && codex.status !== null) {
    const status = String(codex.status).trim();
    if (!CODEX_STATUS.has(status)) return undefined;
    out.status = status;
  }

  const collectedAt = parseIsoOptional(codex.collectedAt);
  if (collectedAt !== undefined) out.collectedAt = collectedAt;

  if (codex.planType !== undefined && codex.planType !== null) {
    out.planType = String(codex.planType).trim().slice(0, 64);
  }

  if (isPlainObject(weeklyRaw)) {
    const weekly = {};
    const usedPercent = parsePercent(weeklyRaw.usedPercent);
    const remainingPercent = parsePercent(weeklyRaw.remainingPercent);
    const windowDurationMins = parsePositiveInt(weeklyRaw.windowDurationMins);
    const resetsAt = parseIsoOptional(weeklyRaw.resetsAt);
    const resetsAtIso = parseIsoOptional(weeklyRaw.resetsAtIso);

    if (usedPercent !== undefined) weekly.usedPercent = usedPercent;
    if (remainingPercent !== undefined) weekly.remainingPercent = remainingPercent;
    if (windowDurationMins !== undefined) {
      weekly.windowDurationMins = windowDurationMins;
    }
    if (resetsAt !== undefined) weekly.resetsAt = resetsAt;
    if (resetsAtIso !== undefined) weekly.resetsAtIso = resetsAtIso;

    if (Object.keys(weekly).length > 0) out.weekly = weekly;
  }

  const picked = {};
  if (Object.keys(out).length > 0) picked.codex = out;

  const cursor = aiUsage.cursor;
  if (isPlainObject(cursor)) {
    const status = String(cursor.status || "unknown").trim();
    const source = String(cursor.source || "").trim();
    if (CURSOR_STATUS.has(status) &&
        (source === "no_official_local_usage_api" || source === "manual")) {
      const c = { status, source };
      const collectedAtCursor = parseIsoOptional(cursor.collectedAt);
      if (collectedAtCursor !== undefined) c.collectedAt = collectedAtCursor;
      const usedPercent = parsePercent(cursor.usedPercent);
      const remainingPercent = parsePercent(cursor.remainingPercent);
      const resetsAt = parseIsoOptional(cursor.resetsAt);
      if (source === "manual") {
        if (usedPercent !== undefined) c.usedPercent = usedPercent;
        if (remainingPercent !== undefined) c.remainingPercent = remainingPercent;
        if (resetsAt !== undefined) c.resetsAt = resetsAt;
      }
      picked.cursor = c;
    }
  }

  if (Object.keys(picked).length === 0) return undefined;
  return picked;
}

module.exports = {
  pickAiUsageCodex,
  CODEX_STATUS,
  CURSOR_STATUS,
};
