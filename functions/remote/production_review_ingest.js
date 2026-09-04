"use strict";

/**
 * ProductionReviewStatusEnvelope live ingest (Control-side).
 * Monotonic Firestore updates + optional outbox notification enqueue.
 * Never creates START_JOB / permits. Never sends FCM directly.
 */

const { COL } = require("./constants");
const { nowIso } = require("./log");
const { loadPolicy, enqueueNotification } = require("./monitoring");

const SCHEMA_VERSION = 1;
const STATUS_COLLECTION = "production_review_status";

const SENSITIVE_KEY_RE =
  /^(token|apiKey|api_key|stackTrace|stack_trace|env|environment|secret|password)$/i;
const WINDOWS_PATH_RE = /^[A-Za-z]:\\|^\\\\/;

const FORBIDDEN_PRODUCTION_TRANSITIONS = {
  completed: new Set(["draft", "in_progress", "prelaunch_review"]),
  registration_ready: new Set(["draft", "in_progress"]),
  failed: new Set(["completed", "registration_ready"]),
};

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

function asInt(v, fallback = 0) {
  if (typeof v === "number" && Number.isFinite(v)) return Math.trunc(v);
  if (typeof v === "string" && v.trim()) {
    const n = Number(v);
    if (Number.isFinite(n)) return Math.trunc(n);
  }
  return fallback;
}

function revisionRankOf(value) {
  const trimmed = String(value || "").trim().toUpperCase();
  if (trimmed.startsWith("R")) {
    const n = Number(trimmed.slice(1));
    return Number.isFinite(n) ? Math.trunc(n) : 0;
  }
  const n = Number(trimmed);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}

function findSensitiveFields(obj, prefix = "") {
  const found = [];
  if (!isPlainObject(obj)) return found;
  for (const [key, value] of Object.entries(obj)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (SENSITIVE_KEY_RE.test(key)) {
      found.push(path);
      continue;
    }
    if (typeof value === "string") {
      if (WINDOWS_PATH_RE.test(value)) found.push(path);
      if (value.includes("stackTrace") || value.includes("apiKey")) found.push(path);
    } else if (isPlainObject(value)) {
      found.push(...findSensitiveFields(value, path));
    }
  }
  return found;
}

function stripSensitiveValues(obj) {
  if (!isPlainObject(obj)) return obj;
  const out = {};
  for (const [key, value] of Object.entries(obj)) {
    if (SENSITIVE_KEY_RE.test(key)) continue;
    if (typeof value === "string" && WINDOWS_PATH_RE.test(value)) continue;
    if (isPlainObject(value)) {
      out[key] = stripSensitiveValues(value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

function normalizeSyncKind(raw) {
  const v = String(raw || "").trim();
  if (v === "baseline" || v === "transition") return v;
  return "";
}

function normalizeEnvelope(raw) {
  if (!isPlainObject(raw)) return null;
  const owner = isPlainObject(raw.ownerReview) ? raw.ownerReview : {};
  const readiness = isPlainObject(raw.readiness) ? raw.readiness : {};
  const tech = isPlainObject(raw.technicalValidation) ? raw.technicalValidation : {};
  const execution = isPlainObject(raw.execution) ? raw.execution : {};
  const problem = isPlainObject(raw.problem) ? raw.problem : {};
  return {
    schemaVersion: asInt(raw.schemaVersion, SCHEMA_VERSION),
    eventId: String(raw.eventId || "").trim(),
    instructionId: String(raw.instructionId || "").trim(),
    projectId: String(raw.projectId || "").trim(),
    jobId: String(raw.jobId || "").trim(),
    artifactType: String(raw.artifactType || "").trim(),
    contentSubtype: String(raw.contentSubtype || "").trim(),
    siteSubtype: String(raw.siteSubtype || "").trim(),
    displayTitle: String(raw.displayTitle || "").trim(),
    revision: String(raw.revision || "").trim(),
    sourceRevision: String(raw.sourceRevision || "").trim(),
    stageId: String(raw.stageId || "").trim(),
    stageOrder: asInt(raw.stageOrder),
    stageStatus: String(raw.stageStatus || "").trim(),
    verifiedThroughStep: asInt(raw.verifiedThroughStep),
    lastVerifiedStage: String(raw.lastVerifiedStage || "").trim(),
    productionStatus: String(raw.productionStatus || "").trim(),
    updatedAt: String(raw.updatedAt || "").trim(),
    emittedAt: String(raw.emittedAt || raw.updatedAt || "").trim(),
    sequence: asInt(raw.sequence),
    technicalValidation: {
      status: String(tech.status || "").trim(),
      completed: tech.completed === true,
      validatorResult: String(tech.validatorResult || "").trim(),
      artifactKind: String(tech.artifactKind || "").trim(),
      artifactSha256: String(tech.artifactSha256 || "").trim(),
      completedAt: String(tech.completedAt || "").trim(),
    },
    ownerReview: {
      decision: String(owner.decision || "").trim(),
      revision: String(owner.revision || "").trim(),
      step16Blocked: owner.step16Blocked === true,
      nextAllowedAction: String(owner.nextAllowedAction || "").trim(),
      findingCount: asInt(owner.findingCount),
      blockerCount: asInt(owner.blockerCount),
      highCount: asInt(owner.highCount),
      decisionRef: String(owner.decisionRef || "").trim(),
      reviewedAt: String(owner.reviewedAt || "").trim(),
    },
    execution: {
      agentState: String(execution.agentState || "").trim(),
      currentJobId: String(execution.currentJobId || "").trim(),
      paused: execution.paused === true,
      recoveryState: String(execution.recoveryState || "").trim(),
      permitState: String(execution.permitState || "").trim(),
      worker: String(execution.worker || "").trim(),
      heartbeatAt: String(execution.heartbeatAt || "").trim(),
      terminalBlockCount: asInt(execution.terminalBlockCount),
    },
    readiness: {
      technicalValidationCompleted: readiness.technicalValidationCompleted === true,
      ownerReviewRequired: readiness.ownerReviewRequired === true,
      revisionRequired: readiness.revisionRequired === true,
      revisionReady: readiness.revisionReady === true,
      registrationEligible: readiness.registrationEligible === true,
      externalPublicationAllowed: readiness.externalPublicationAllowed === true,
    },
    problem: {
      code: String(problem.code || "").trim(),
      severity: String(problem.severity || "").trim(),
      userSummary: String(problem.userSummary || "").trim(),
      recommendedActions: Array.isArray(problem.recommendedActions)
        ? problem.recommendedActions.map((x) => String(x))
        : [],
      occurredAt: String(problem.occurredAt || "").trim(),
    },
    userLabelKo: String(raw.userLabelKo || "").trim(),
    nextActionKo: String(raw.nextActionKo || "").trim(),
    initialSync: raw.initialSync === true,
    syncKind: normalizeSyncKind(raw.syncKind),
    contentFingerprint: String(raw.contentFingerprint || "").trim(),
  };
}

function isStaleVs(incoming, stored) {
  if (!stored) return false;
  if (incoming.instructionId !== stored.instructionId) return false;
  if (revisionRankOf(incoming.revision) !== revisionRankOf(stored.revision)) {
    return false;
  }
  const otherEmitted = Date.parse(stored.emittedAt || "");
  const thisEmitted = Date.parse(incoming.emittedAt || "");
  if (Number.isFinite(otherEmitted) && Number.isFinite(thisEmitted)) {
    if (thisEmitted < otherEmitted) return true;
    if (thisEmitted === otherEmitted && incoming.sequence < stored.sequence) {
      return true;
    }
  } else if (incoming.sequence < asInt(stored.sequence)) {
    return true;
  }
  return false;
}

function checkDecisionConsistency(e) {
  if (e.ownerReview.decision !== "changes_requested") return null;
  if (e.readiness.externalPublicationAllowed) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_CHANGES_EXTERNAL",
      message: "changes_requested cannot allow external publication",
    };
  }
  if (e.readiness.registrationEligible) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_CHANGES_REGISTRATION",
      message: "changes_requested cannot be registration eligible",
    };
  }
  if (!e.ownerReview.step16Blocked) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_CHANGES_STEP16",
      message: "changes_requested requires step16Blocked",
    };
  }
  return null;
}

function checkForbiddenTransition(stored, incoming) {
  if (revisionRankOf(incoming.revision) > revisionRankOf(stored.revision)) {
    return null;
  }
  const from = String(stored.productionStatus || "").trim();
  const to = String(incoming.productionStatus || "").trim();
  if (!from || !to || from === to) return null;
  const forbidden = FORBIDDEN_PRODUCTION_TRANSITIONS[from];
  if (forbidden && forbidden.has(to)) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_FORBIDDEN_TRANSITION",
      message: `productionStatus ${from} → ${to} not allowed`,
    };
  }
  if (
    stored.ownerReview &&
    stored.ownerReview.decision === "approved" &&
    incoming.ownerReview.decision === "pending" &&
    revisionRankOf(incoming.revision) === revisionRankOf(stored.revision)
  ) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_OWNER_REOPEN",
      message: "cannot reopen approved revision to pending",
    };
  }
  return null;
}

/**
 * Sanitize + validate envelope against optional stored state.
 * @returns {{ok, duplicate?, rejected?, code, message?, sanitized?, strippedFields?}}
 */
function sanitizeAndValidate(envelope, stored) {
  if (!isPlainObject(envelope)) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_NOT_OBJECT",
      message: "productionReviewStatus must be an object",
    };
  }

  const sensitive = findSensitiveFields(envelope);
  if (sensitive.length > 0) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_SENSITIVE_FIELD",
      message: "sensitive fields present",
      strippedFields: sensitive,
    };
  }

  const sanitized = normalizeEnvelope(stripSensitiveValues(envelope));
  if (!sanitized) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_NOT_OBJECT",
      message: "productionReviewStatus must be an object",
    };
  }

  if (sanitized.schemaVersion !== SCHEMA_VERSION) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_SCHEMA_VERSION",
      message: "unsupported schemaVersion",
    };
  }

  if (!sanitized.eventId || !sanitized.instructionId) {
    return {
      ok: false,
      rejected: true,
      code: "PRSE_MISSING_IDS",
      message: "eventId and instructionId required",
    };
  }

  const storedNorm = stored ? normalizeEnvelope(stored) : null;
  if (storedNorm && storedNorm.eventId && storedNorm.eventId === sanitized.eventId) {
    return {
      ok: true,
      duplicate: true,
      code: "PRSE_DUPLICATE_EVENT",
      message: "duplicate eventId",
      sanitized,
    };
  }

  if (storedNorm) {
    if (revisionRankOf(sanitized.revision) < revisionRankOf(storedNorm.revision)) {
      return {
        ok: false,
        rejected: true,
        code: "PRSE_REVISION_ROLLBACK",
        message: "revision rollback rejected",
      };
    }
    if (isStaleVs(sanitized, storedNorm)) {
      return {
        ok: false,
        rejected: true,
        code: "PRSE_STALE_EVENT",
        message: "stale event rejected",
      };
    }
    const transitionErr = checkForbiddenTransition(storedNorm, sanitized);
    if (transitionErr) return transitionErr;
  }

  const consistencyErr = checkDecisionConsistency(sanitized);
  if (consistencyErr) return consistencyErr;

  return {
    ok: true,
    code: "PRSE_OK",
    sanitized,
  };
}

/**
 * Map envelope transition to monitoring eventType, or null.
 */
function resolveNotificationEventType(envelope, stored) {
  const incoming = normalizeEnvelope(envelope);
  if (!incoming) return null;
  const prev = stored ? normalizeEnvelope(stored) : null;
  const decision = incoming.ownerReview.decision;
  const readiness = incoming.readiness;
  const prevReadiness = prev ? prev.readiness : null;

  if (decision === "changes_requested") {
    if (!prev || prev.ownerReview.decision !== "changes_requested") {
      return "owner_review_changes_requested";
    }
    return "owner_review_changes_requested";
  }

  if (
    readiness.revisionReady === true &&
    (!prevReadiness || prevReadiness.revisionReady !== true)
  ) {
    return "r2_revision_ready";
  }

  if (
    readiness.registrationEligible === true &&
    (!prevReadiness || prevReadiness.registrationEligible !== true)
  ) {
    return "registration_ready";
  }

  if (
    String(incoming.productionStatus || "").includes("failed") ||
    (incoming.problem && incoming.problem.code)
  ) {
    return "production_failed";
  }

  if (
    decision === "pending" &&
    readiness.ownerReviewRequired === true &&
    (!prev || prev.ownerReview.decision !== "pending")
  ) {
    return "owner_review_required";
  }

  if (
    readiness.technicalValidationCompleted === true &&
    (!prevReadiness || prevReadiness.technicalValidationCompleted !== true)
  ) {
    return "technical_validation_completed";
  }

  return null;
}

/**
 * Whether notification enqueue should be suppressed for this apply.
 */
function shouldSuppressNotification({ incoming, stored, isBaseline }) {
  const env = normalizeEnvelope(incoming) || incoming || {};
  if (isBaseline === true) return true;
  if (env.initialSync === true) return true;
  if (normalizeSyncKind(env.syncKind) === "baseline") return true;
  const fp = String(env.contentFingerprint || "").trim();
  const storedFp = stored
    ? String((normalizeEnvelope(stored) || stored).contentFingerprint || "").trim()
    : "";
  if (fp && storedFp && fp === storedFp) return true;
  const eventId = String(env.eventId || "").trim();
  const storedEventId = stored
    ? String((normalizeEnvelope(stored) || stored).eventId || "").trim()
    : "";
  if (eventId && storedEventId && eventId === storedEventId) return true;
  return false;
}

async function defaultEnqueue(db, data) {
  try {
    const policy = await loadPolicy(db);
    return await enqueueNotification(db, data, policy);
  } catch (err) {
    console.error(JSON.stringify({
      type: "production_review_notification_enqueue_failed",
      eventType: data.eventType,
      instructionId: data.instructionId || "",
      code: String((err && (err.code || err.message)) || "error").slice(0, 160),
    }));
    return { created: false, error: true };
  }
}

/**
 * Apply production review status envelope (monotonic transaction).
 * Stores under production_review_status/{instructionId} and optionally
 * merges productionReviewStatus onto sotong24work_projects/{instructionId|projectId}.
 *
 * @param {object} db
 * @param {object} envelope
 * @param {{agentId?: string, enqueueFn?: Function, now?: string}} [options]
 * @returns {Promise<{ok, duplicate, rejected, applied, notificationEnqueued, code, message?}>}
 */
async function applyProductionReviewStatus(db, envelope, options = {}) {
  const agentId = String(options.agentId || "").trim();
  const enqueueFn =
    typeof options.enqueueFn === "function" ? options.enqueueFn : defaultEnqueue;
  const ts = String(options.now || nowIso());

  if (!isPlainObject(envelope)) {
    return {
      ok: false,
      duplicate: false,
      rejected: true,
      applied: false,
      notificationEnqueued: false,
      code: "PRSE_NOT_OBJECT",
    };
  }

  const instructionIdHint = String(envelope.instructionId || "").trim();
  if (!instructionIdHint) {
    return {
      ok: false,
      duplicate: false,
      rejected: true,
      applied: false,
      notificationEnqueued: false,
      code: "PRSE_MISSING_IDS",
    };
  }

  const statusRef = db.collection(STATUS_COLLECTION).doc(instructionIdHint);
  let applyOutcome = {
    ok: false,
    duplicate: false,
    rejected: false,
    applied: false,
    notificationEnqueued: false,
    code: "PRSE_INTERNAL",
    sanitized: null,
    stored: null,
    isBaseline: false,
  };

  await db.runTransaction(async (tx) => {
    // Firestore: all reads before any writes.
    const snap = await tx.get(statusRef);
    const stored = snap.exists ? snap.data() || null : null;
    const validation = sanitizeAndValidate(envelope, stored);

    if (!validation.ok) {
      applyOutcome = {
        ok: false,
        duplicate: false,
        rejected: true,
        applied: false,
        notificationEnqueued: false,
        code: validation.code || "PRSE_REJECTED",
        message: validation.message || "",
        sanitized: null,
        stored,
        isBaseline: false,
      };
      return;
    }

    if (validation.duplicate) {
      applyOutcome = {
        ok: true,
        duplicate: true,
        rejected: false,
        applied: false,
        notificationEnqueued: false,
        code: validation.code || "PRSE_DUPLICATE_EVENT",
        sanitized: validation.sanitized,
        stored,
        isBaseline: false,
      };
      return;
    }

    const sanitized = { ...validation.sanitized, updatedAt: ts };
    const isBaseline =
      sanitized.initialSync === true ||
      sanitized.syncKind === "baseline";

    const projectIds = [];
    if (sanitized.instructionId) projectIds.push(sanitized.instructionId);
    if (
      sanitized.projectId &&
      sanitized.projectId !== sanitized.instructionId
    ) {
      projectIds.push(sanitized.projectId);
    }

    const existingProjectRefs = [];
    for (const pid of projectIds) {
      const projectRef = db.collection(COL.PROJECTS).doc(pid);
      const projectSnap = await tx.get(projectRef);
      if (projectSnap.exists) existingProjectRefs.push(projectRef);
    }

    tx.set(statusRef, sanitized, { merge: false });
    for (const projectRef of existingProjectRefs) {
      // Merge ONLY productionReviewStatus — do not wipe other project fields.
      tx.set(
        projectRef,
        { productionReviewStatus: sanitized },
        { merge: true }
      );
    }

    applyOutcome = {
      ok: true,
      duplicate: false,
      rejected: false,
      applied: true,
      notificationEnqueued: false,
      code: "PRSE_APPLIED",
      sanitized,
      stored,
      isBaseline,
    };
  });

  if (!applyOutcome.ok || applyOutcome.duplicate || !applyOutcome.applied) {
    return {
      ok: applyOutcome.ok,
      duplicate: applyOutcome.duplicate,
      rejected: applyOutcome.rejected,
      applied: applyOutcome.applied,
      notificationEnqueued: false,
      code: applyOutcome.code,
      message: applyOutcome.message || "",
    };
  }

  const sanitized = applyOutcome.sanitized;
  const stored = applyOutcome.stored;
  const isBaseline = applyOutcome.isBaseline === true;

  // Baseline / initialSync: always skip enqueue entirely.
  if (isBaseline) {
    return {
      ok: true,
      duplicate: false,
      rejected: false,
      applied: true,
      notificationEnqueued: false,
      code: "PRSE_APPLIED",
    };
  }

  const suppress = shouldSuppressNotification({
    incoming: sanitized,
    stored,
    isBaseline: false,
  });
  if (suppress) {
    return {
      ok: true,
      duplicate: false,
      rejected: false,
      applied: true,
      notificationEnqueued: false,
      code: "PRSE_APPLIED",
    };
  }

  const eventType = resolveNotificationEventType(sanitized, stored);
  if (!eventType) {
    return {
      ok: true,
      duplicate: false,
      rejected: false,
      applied: true,
      notificationEnqueued: false,
      code: "PRSE_APPLIED",
    };
  }

  let ownerUid = "";
  if (agentId) {
    try {
      const agentSnap = await db.collection(COL.AGENTS).doc(agentId).get();
      if (agentSnap.exists) {
        ownerUid = String((agentSnap.data() || {}).ownerUid || "");
      }
    } catch (_) {
      ownerUid = "";
    }
  }

  const revisionNum = revisionRankOf(sanitized.revision) || 1;
  const out = await enqueueFn(db, {
    ownerUid,
    instructionId: sanitized.instructionId,
    jobId: sanitized.jobId || "",
    stageId: sanitized.stageId || "",
    stageNumber: sanitized.stageOrder || 0,
    stageName: sanitized.lastVerifiedStage || sanitized.stageId || "owner_review",
    revision: revisionNum,
    eventType,
    severity: eventType === "production_failed" ? "critical" : "info",
    actionRequired:
      eventType === "owner_review_changes_requested" ||
      eventType === "owner_review_required" ||
      eventType === "production_failed" ||
      eventType === "recovery_action_required",
    source: "production_review_ingest",
    productType: sanitized.artifactType || "app",
    appName: sanitized.displayTitle || "",
  });

  return {
    ok: true,
    duplicate: false,
    rejected: false,
    applied: true,
    notificationEnqueued: !!(out && out.created !== false && !out.error),
    code: "PRSE_APPLIED",
  };
}

module.exports = {
  STATUS_COLLECTION,
  SCHEMA_VERSION,
  sanitizeAndValidate,
  resolveNotificationEventType,
  shouldSuppressNotification,
  applyProductionReviewStatus,
  normalizeEnvelope,
  revisionRankOf,
};
