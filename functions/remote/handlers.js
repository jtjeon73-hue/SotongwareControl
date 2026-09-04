"use strict";

const {
  COL,
  COMMAND_STATUS,
  WORK_STATUS,
  AGENT_STATE,
  PROTOCOL_VERSION,
  PAIRING_TTL_MS,
  PULL_DEFAULT_LIMIT,
  PULL_MAX_LIMIT,
  ONLINE_WITHIN_MS,
  COMMAND_TYPE,
  ACTIVITY_STATE,
  ACTIVITY_TYPE,
} = require("./constants");
const {
  sha256Hex,
  randomToken,
  randomPairingCode,
  newId,
} = require("./crypto_util");
const { httpError, sendOk } = require("./http");
const { nowIso } = require("./log");
const { assertProtocolVersion } = require("./auth");
const { pickAiUsageCodex } = require("./ai_usage");
const { loadPolicy, enqueueNotification } = require("./monitoring");
const {
  mergeMonotonicStage,
  mergeMonotonicProject,
} = require("../sotong24/writer");
const { EBOOK_STAGE_BY_ID, APP_STAGE_BY_ID } = require("../sotong24/canonical");
const { handleCancelJob } = require("./cancellation");
const {
  applyProductionReviewStatus,
} = require("./production_review_ingest");

const AGENT_STATES = new Set(Object.values(AGENT_STATE));
const WORK_STATUSES = new Set(Object.values(WORK_STATUS));
const ACTIVITY_STATES = new Set(Object.values(ACTIVITY_STATE));
const ACTIVITY_TYPES = new Set(Object.values(ACTIVITY_TYPE));

async function mirrorMonitoring(db, instructionId, stageId, stagePatch, projectPatch) {
  if (!instructionId || !stageId) return;
  const projectRef = db.collection(COL.PROJECTS).doc(instructionId);
  const projectSnap = await projectRef.get();
  if (!projectSnap.exists) return;
  await db.runTransaction(async (tx) => {
    await tx.set(projectRef.collection("stages").doc(stageId), stagePatch, { merge: true });
    await tx.set(projectRef, projectPatch, { merge: true });
  });
}

async function queueNotificationSafely(db, data) {
  try {
    const policy = await loadPolicy(db);
    return await enqueueNotification(db, data, policy);
  } catch (err) {
    // Notification is an observer. A delivery/outbox failure must never roll
    // back or alter the authoritative stage/job transition.
    console.error(JSON.stringify({
      type: "notification_enqueue_failed",
      eventType: data.eventType,
      jobId: data.jobId || "",
      stageId: data.stageId || "",
      code: String(err && (err.code || err.message) || "error").slice(0, 160),
    }));
    return { created: false, error: true };
  }
}

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

async function handleEnroll(db, body) {
  assertProtocolVersion(body);
  const pairingCode = String(body.pairingCode || "").trim();
  const deviceName = String(body.deviceName || "device").trim().slice(0, 120);
  const appVersion = String(body.appVersion || "").trim().slice(0, 120);
  if (!pairingCode) throw httpError(400, "bad_request", "pairingCode required");

  const codeHash = sha256Hex(pairingCode.toUpperCase());
  // Find unused session by codeHash (scan limited — also store codeHash as doc id optional)
  const q = await db
    .collection(COL.PAIRING)
    .where("codeHash", "==", codeHash)
    .where("used", "==", false)
    .limit(5)
    .get();

  if (q.empty) throw httpError(403, "bad_pairing", "invalid_or_used");

  const now = Date.now();
  let sessionDoc = null;
  for (const doc of q.docs) {
    const data = doc.data() || {};
    const exp = data.expiresAt && data.expiresAt.toMillis
      ? data.expiresAt.toMillis()
      : Date.parse(data.expiresAt || "") || 0;
    if (exp && exp < now) continue;
    sessionDoc = doc;
    break;
  }
  if (!sessionDoc) throw httpError(403, "bad_pairing", "expired");

  const session = sessionDoc.data() || {};
  const ownerUid = String(session.ownerUid || "");
  if (!ownerUid) throw httpError(500, "internal", "pairing_owner_missing");

  const agentId = newId("agent");
  const agentToken = randomToken(32);
  const tokenHash = sha256Hex(agentToken);
  const ts = nowIso();

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(sessionDoc.ref);
    if (!fresh.exists) throw httpError(403, "bad_pairing", "invalid_or_used");
    const d = fresh.data() || {};
    if (d.used === true) throw httpError(403, "bad_pairing", "already_used");
    const exp = d.expiresAt && d.expiresAt.toMillis
      ? d.expiresAt.toMillis()
      : Date.parse(d.expiresAt || "") || 0;
    if (exp && exp < Date.now()) throw httpError(403, "bad_pairing", "expired");

    tx.set(db.collection(COL.AGENTS).doc(agentId), {
      agentId,
      ownerUid,
      deviceName,
      state: AGENT_STATE.IDLE,
      online: false,
      enabled: true,
      lastHeartbeatAt: null,
      appVersion,
      protocolVersion: PROTOCOL_VERSION,
      currentJobId: "",
      currentStage: "",
      tokenHash,
      createdAt: ts,
      updatedAt: ts,
    });
    tx.set(db.collection(COL.AGENT_TOKENS).doc(tokenHash), {
      agentId,
      ownerUid,
      createdAt: ts,
    });
    tx.update(sessionDoc.ref, {
      used: true,
      usedAt: ts,
      agentId,
      updatedAt: ts,
    });
  });

  return { agentId, agentToken };
}

async function handleHeartbeat(db, ctx, body) {
  const state = String(body.state || "").trim();
  if (state && !AGENT_STATES.has(state)) {
    throw httpError(400, "invalid_payload", "state invalid");
  }
  const ts = nowIso();
  const patch = {
    updatedAt: ts,
    lastHeartbeatAt: ts,
    protocolVersion: PROTOCOL_VERSION,
  };
  if (state) patch.state = state;
  const deviceName = String(body.deviceName || "").trim().slice(0, 120);
  if (deviceName) patch.deviceName = deviceName;
  if (body.appVersion != null) patch.appVersion = String(body.appVersion).slice(0, 120);
  if (body.currentJobId != null) patch.currentJobId = String(body.currentJobId).slice(0, 128);
  if (body.currentStage != null) patch.currentStage = String(body.currentStage).slice(0, 128);
  // online is derived by clients from lastHeartbeatAt — keep mirror hint false here
  patch.online = false;

  const aiUsage = pickAiUsageCodex(body);
  if (aiUsage !== undefined) {
    patch.aiUsage = aiUsage;
  }

  await ctx.agentRef.set(patch, { merge: true });

  // Optional production review envelope — reject must NOT fail heartbeat.
  if (isPlainObject(body.productionReviewStatus)) {
    try {
      const result = await applyProductionReviewStatus(
        db,
        body.productionReviewStatus,
        { agentId: ctx.agentId }
      );
      if (result.rejected || !result.ok) {
        console.error(JSON.stringify({
          type: "production_review_status_rejected",
          agentId: ctx.agentId || "",
          instructionId: String(
            body.productionReviewStatus.instructionId || ""
          ).slice(0, 128),
          code: String(result.code || "PRSE_REJECTED").slice(0, 80),
        }));
      }
    } catch (err) {
      console.error(JSON.stringify({
        type: "production_review_status_ingest_error",
        agentId: ctx.agentId || "",
        code: String((err && (err.code || err.message)) || "error").slice(0, 160),
      }));
    }
  }

  return {};
}

function commandRef(db, jobId, commandId) {
  return db.collection(COL.JOBS).doc(jobId).collection("commands").doc(commandId);
}

async function handlePull(db, ctx, body) {
  let limit = PULL_DEFAULT_LIMIT;
  if (body.limit != null && body.limit !== "") {
    const n = Number(body.limit);
    if (!Number.isInteger(n) || n < 1 || n > PULL_MAX_LIMIT) {
      throw httpError(400, "invalid_payload", "limit out_of_range");
    }
    limit = n;
  }

  const snap = await db
    .collectionGroup("commands")
    .where("agentId", "==", ctx.agentId)
    .where("status", "==", COMMAND_STATUS.QUEUED)
    .orderBy("createdAt", "asc")
    .limit(limit)
    .get();

  const commands = snap.docs.map((d) => {
    const c = d.data() || {};
    return {
      commandId: c.commandId || d.id,
      idempotencyKey: c.idempotencyKey || "",
      agentId: c.agentId || ctx.agentId,
      jobId: c.jobId || "",
      type: c.type || "",
      createdAt: c.createdAt || "",
      payload: isPlainObject(c.payload) ? c.payload : {},
      status: c.status || COMMAND_STATUS.QUEUED,
    };
  });
  return { commands };
}

async function handleClaim(db, ctx, body) {
  const commandId = String(body.commandId || "").trim();
  const jobId = String(body.jobId || "").trim();
  if (!commandId || !jobId) throw httpError(400, "invalid_payload", "commandId_and_jobId required");

  const ref = commandRef(db, jobId, commandId);
  const ts = nowIso();

  // Firestore requires all transaction reads before any writes.
  const result = await db.runTransaction(async (tx) => {
    const jobRef = db.collection(COL.JOBS).doc(jobId);
    const [snap, jobSnap] = await Promise.all([tx.get(ref), tx.get(jobRef)]);
    if (!snap.exists) throw httpError(404, "not_found", "command_missing");
    const cmd = snap.data() || {};
    if (cmd.agentId !== ctx.agentId) throw httpError(403, "forbidden", "agent_mismatch");

    if (cmd.status === COMMAND_STATUS.CLAIMED) {
      return { alreadyClaimed: true };
    }
    if (cmd.status !== COMMAND_STATUS.QUEUED) {
      throw httpError(409, "not_claimable", `status=${cmd.status}`);
    }

    tx.update(ref, {
      status: COMMAND_STATUS.CLAIMED,
      claimedAt: ts,
      updatedAt: ts,
      attempt: (cmd.attempt || 0) + 1,
    });

    if (jobSnap.exists) {
      tx.update(jobRef, {
        status: WORK_STATUS.CLAIMED,
        updatedAt: ts,
      });
    }
    return { alreadyClaimed: false };
  });

  return result;
}

async function handleComplete(db, ctx, body) {
  const commandId = String(body.commandId || "").trim();
  const jobId = String(body.jobId || "").trim();
  if (!commandId || !jobId) throw httpError(400, "invalid_payload", "commandId_and_jobId required");
  const summary = String(body.summary || "").slice(0, 2000);
  const ts = nowIso();
  const ref = commandRef(db, jobId, commandId);
  const DISMISS_SUMMARIES = new Set([
    "duplicate_skipped",
    "cancelled_preserved_blocked",
    "job_cancelled_skipped",
    "dismissed",
  ]);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw httpError(404, "not_found", "command_missing");
    const cmd = snap.data() || {};
    if (cmd.agentId !== ctx.agentId) throw httpError(403, "forbidden", "agent_mismatch");
    if (cmd.status === COMMAND_STATUS.COMPLETED) return;
    if (cmd.status === COMMAND_STATUS.FAILED) return;
    if (cmd.status === COMMAND_STATUS.QUEUED && DISMISS_SUMMARIES.has(summary)) {
      tx.update(ref, {
        status: COMMAND_STATUS.COMPLETED,
        completedAt: ts,
        updatedAt: ts,
        summary,
      });
      return;
    }
    if (cmd.status !== COMMAND_STATUS.CLAIMED) {
      throw httpError(409, "not_completable", `status=${cmd.status}`);
    }
    tx.update(ref, {
      status: COMMAND_STATUS.COMPLETED,
      completedAt: ts,
      updatedAt: ts,
      summary,
    });
  });
  return {};
}

async function handleFail(db, ctx, body) {
  const commandId = String(body.commandId || "").trim();
  const jobId = String(body.jobId || "").trim();
  if (!commandId || !jobId) throw httpError(400, "invalid_payload", "commandId_and_jobId required");
  const code = String(body.code || "error").slice(0, 120);
  const message = String(body.message || "").slice(0, 500);
  const retryable = body.retryable === true;
  const ts = nowIso();
  const ref = commandRef(db, jobId, commandId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw httpError(404, "not_found", "command_missing");
    const cmd = snap.data() || {};
    if (cmd.agentId !== ctx.agentId) throw httpError(403, "forbidden", "agent_mismatch");
    if (cmd.status === COMMAND_STATUS.FAILED) return;
    if (cmd.status === COMMAND_STATUS.COMPLETED) return;
    if (
      cmd.status !== COMMAND_STATUS.QUEUED &&
      cmd.status !== COMMAND_STATUS.CLAIMED
    ) {
      throw httpError(409, "not_failable", `status=${cmd.status}`);
    }
    tx.update(ref, {
      status: COMMAND_STATUS.FAILED,
      failedAt: ts,
      completedAt: ts,
      updatedAt: ts,
      error: { code, message, retryable },
    });
  });
  return {};
}

async function handleReportState(db, ctx, body) {
  const state = String(body.state || "").trim();
  if (!AGENT_STATES.has(state)) throw httpError(400, "invalid_payload", "state invalid");
  const ts = nowIso();
  await ctx.agentRef.set(
    {
      state,
      updatedAt: ts,
      lastHeartbeatAt: ts,
    },
    { merge: true }
  );
  return {};
}

async function handleReportJob(db, ctx, body) {
  const jobId = String(body.jobId || "").trim();
  const status = String(body.status || "").trim();
  if (!jobId) throw httpError(400, "invalid_payload", "jobId required");
  if (!WORK_STATUSES.has(status)) throw httpError(400, "invalid_payload", "status invalid");
  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const snap = await jobRef.get();
  if (!snap.exists) throw httpError(404, "not_found", "job_missing");
  const job = snap.data() || {};
  if (job.assignedAgentId && job.assignedAgentId !== ctx.agentId) {
    throw httpError(403, "forbidden", "agent_mismatch");
  }
  if (job.ownerUid && ctx.agent.ownerUid && job.ownerUid !== ctx.agent.ownerUid) {
    throw httpError(403, "forbidden", "owner_mismatch");
  }

  const ts = nowIso();
  const patch = {
    status,
    updatedAt: ts,
    assignedAgentId: job.assignedAgentId || ctx.agentId,
    ownerUid: job.ownerUid || ctx.agent.ownerUid,
  };
  if (status === WORK_STATUS.RUNNING && !job.startedAt) patch.startedAt = ts;
  if (status === WORK_STATUS.COMPLETED) patch.completedAt = ts;
  await jobRef.set(patch, { merge: true });
  const completionStageId = String(body.currentStage || job.currentStage || "");
  const productType = String(body.productType || job.productType || job.type || "ebook");
  const completionStage = productType === "app"
    ? APP_STAGE_BY_ID.get(completionStageId)
    : EBOOK_STAGE_BY_ID.get(completionStageId);
  const completionStageNumber = Number(
    body.currentStageNumber || job.currentStageNumber || completionStage?.order
  ) || 0;
  const isProductionBoundary = status === WORK_STATUS.COMPLETED &&
    (completionStage?.productionBoundary === true || completionStage?.terminal === true) &&
    completionStageNumber === 18;
  if (isProductionBoundary) {
    await queueNotificationSafely(db, {
      ownerUid: job.ownerUid || ctx.agent.ownerUid || "",
      instructionId: job.instructionId || "",
      jobId,
      stageId: completionStageId,
      stageNumber: completionStageNumber,
      stageName: "최종 제작",
      revision: Number(body.revision) || 1,
      eventType: "production_completed",
      productType,
      severity: "info",
      actionRequired: false,
    });
  }
  return {};
}

function toProjectStageStatus(status) {
  if (status === WORK_STATUS.WAITING_APPROVAL) return "awaiting_approval";
  if (status === WORK_STATUS.RUNNING || status === WORK_STATUS.REWORKING ||
      status === WORK_STATUS.CLAIMED) return "in_progress";
  if (status === WORK_STATUS.FAILED) return "error";
  if (status === WORK_STATUS.REVISION_REQUESTED) return "revision";
  if (status === WORK_STATUS.PAUSED_QUOTA || status === WORK_STATUS.PAUSED_NETWORK ||
      status === WORK_STATUS.STALLED || status === WORK_STATUS.AI_PROCESS_FAILED ||
      status === WORK_STATUS.RESULT_VALIDATION_RETRYING ||
      status === WORK_STATUS.RESULT_VALIDATION_FAILED ||
      status === WORK_STATUS.STAGE_TRANSITION_FAILED) return status;
  return status;
}

// Reconcile an existing durable task without claiming a command or launching it.
async function reportRecoveredStage(db, ctx, body) {
  const { jobId, instructionId, stageId, taskId } = body;
  const revision = body.revision;
  if (body.status !== WORK_STATUS.PAUSED || !Number.isSafeInteger(revision) || revision < 1 ||
      !instructionId || !stageId || taskId !== `${instructionId}__${stageId}__r${revision}`) {
    throw httpError(400, "invalid_payload", "recovered_task_identity_invalid");
  }
  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const stageRef = jobRef.collection("stages").doc(stageId);
  const projectRef = db.collection(COL.PROJECTS).doc(instructionId);
  const projectStageRef = projectRef.collection("stages").doc(stageId);
  const ts = nowIso();
  await db.runTransaction(async (tx) => {
    const refs = [jobRef, stageRef, projectRef, projectStageRef];
    const snaps = await Promise.all(refs.map((ref) => tx.get(ref)));
    if (snaps.some((s) => !s.exists)) throw httpError(409, "failed_precondition", "recovery_requires_existing_records");
    const [job, stage, project, projectStage] = snaps.map((s) => s.data() || {});
    if (job.assignedAgentId !== ctx.agentId || (job.ownerUid && job.ownerUid !== ctx.agent.ownerUid))
      throw httpError(403, "forbidden", "agent_mismatch");
    if (job.instructionId !== instructionId || job.currentStage !== stageId ||
        Number(job.currentStageNumber || stage.stageNumber) !== body.stageNumber ||
        Number(project.currentStage) !== body.stageNumber ||
        (project.currentStageId && project.currentStageId !== stageId))
      throw httpError(409, "failed_precondition", "recovery_current_stage_mismatch");
    if (revision !== Math.max(Number(stage.revision) || 1, Number(projectStage.revision) || 1))
      throw httpError(409, "failed_precondition", "recovery_revision_not_existing");
    if ([job, stage, project, projectStage].some((s) =>
      ["completed", "cancelled", "not_applicable", "waiting_approval", "awaiting_approval"].includes(s.status)))
      throw httpError(409, "failed_precondition", "terminal_task_not_recoverable");
    const common = { status: WORK_STATUS.PAUSED, recoveryState: "safe_stopped",
      taskId, revision, recoveredTaskId: taskId, lastActivityAt: ts, updatedAt: ts,
      activityState: "safe_stopped", failureType: "", failureReason: "", errorMessage: "",
      pauseReason: "operator_verification", retryable: false, nextRetryAt: "" };
    for (let i = 0; i < refs.length; i++) {
      const prior = snaps[i].data() || {};
      const patch = { ...common };
      // Preserve failure/counter evidence; never reset the attempt budget.
      if (prior.recoveredTaskId !== taskId) patch.recoveryHistory = [
        ...(Array.isArray(prior.recoveryHistory) ? prior.recoveryHistory : []),
        { at: ts, taskId, previousRevision: Number(prior.revision) || 1,
          previousStatus: prior.status || "", failureType: prior.failureType || "",
          failureReason: prior.failureReason || "", recoveryAttempt: Number(prior.recoveryAttempt) || 0 },
      ];
      tx.set(refs[i], patch, { merge: true });
    }
  });
  return { recoveryState: "safe_stopped", taskId, revision };
}

async function handleReportStage(db, ctx, body) {
  const stageId = String(body.stageId || "").trim();
  const status = String(body.status || "").trim();
  const jobId = String(body.jobId || ctx.agent.currentJobId || "").trim();
  if (!stageId) throw httpError(400, "invalid_payload", "stageId required");
  if (!jobId) throw httpError(400, "invalid_payload", "jobId required");
  if (!WORK_STATUSES.has(status)) throw httpError(400, "invalid_payload", "status invalid");
  if (body.recoveryState === "safe_stopped") return reportRecoveredStage(db, ctx, body);
  const reportsCompletion =
    status === WORK_STATUS.COMPLETED || status === WORK_STATUS.WAITING_APPROVAL;
  if (reportsCompletion && body.criteriaMet !== true) {
    throw httpError(409, "failed_precondition", "criteriaMet_true_required");
  }
  if (status === WORK_STATUS.WAITING_APPROVAL && body.approvalRequired !== true) {
    throw httpError(409, "failed_precondition", "approvalRequired_true_required");
  }

  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) throw httpError(404, "not_found", "job_missing");
  const job = jobSnap.data() || {};
  const productType = String(body.productType || job.productType || job.type || "ebook");
  const stageDefinition = productType === "app"
    ? APP_STAGE_BY_ID.get(stageId)
    : EBOOK_STAGE_BY_ID.get(stageId);
  if (job.assignedAgentId && job.assignedAgentId !== ctx.agentId) {
    throw httpError(403, "forbidden", "agent_mismatch");
  }

  const ts = nowIso();
  const stageRef = jobRef.collection("stages").doc(stageId);
  const prev = await stageRef.get();
  const patch = {
    stageId,
    status,
    updatedAt: ts,
  };
  if (body.progress != null) patch.progress = Number(body.progress) || 0;
  if (body.summary != null) patch.summary = String(body.summary).slice(0, 2000);
  if (body.stageName != null) patch.stageName = String(body.stageName).slice(0, 120);
  if (body.stageNumber != null) patch.stageNumber = Number(body.stageNumber) || 0;
  if (body.revision != null) patch.revision = Math.max(1, Number(body.revision) || 1);
  if (body.approvalRequired != null) patch.approvalRequired = body.approvalRequired === true;
  if (body.criteriaMet != null) patch.criteriaMet = body.criteriaMet === true;
  for (const field of ["attemptCount", "maxAttempts", "retryCount", "maxRetries"]) {
    if (body[field] != null) patch[field] = Math.max(0, Number(body[field]) || 0);
  }
  if (body.nextRetryAt != null) patch.nextRetryAt = String(body.nextRetryAt).slice(0, 80);
  if (body.failureReason != null) patch.failureReason = String(body.failureReason).slice(0, 240);
  if (body.failureType != null) patch.failureType = String(body.failureType).slice(0, 40);
  if (body.retryable != null) patch.retryable = body.retryable === true;
  const previous = prev.exists ? prev.data() || {} : {};
  for (const field of ["attemptCount", "maxAttempts", "retryCount", "maxRetries",
    "failureType", "failureReason"]) {
    if (patch[field] == null && previous[field] != null) patch[field] = previous[field];
  }
  if (status === WORK_STATUS.RUNNING || status === WORK_STATUS.REWORKING) {
    patch.retryable = false;
    patch.nextRetryAt = "";
  }
  const activeStatus = new Set([
    WORK_STATUS.CLAIMED,
    WORK_STATUS.RUNNING,
    WORK_STATUS.REWORKING,
  ]);
  const interruptionStatus = new Set([
    WORK_STATUS.PAUSED_QUOTA,
    WORK_STATUS.PAUSED_NETWORK,
    WORK_STATUS.STALLED,
    WORK_STATUS.AI_PROCESS_FAILED,
    WORK_STATUS.RESULT_VALIDATION_RETRYING,
    WORK_STATUS.RESULT_VALIDATION_FAILED,
    WORK_STATUS.STAGE_TRANSITION_FAILED,
  ]);
  if (!previous.startedAt && activeStatus.has(status)) patch.startedAt = ts;
  patch.lastActivityAt = ts;
  patch.activityType = status === WORK_STATUS.WAITING_APPROVAL
    ? ACTIVITY_TYPE.APPROVAL_TRANSITION
    : ACTIVITY_TYPE.STAGE_STATUS;
  if (status === WORK_STATUS.RUNNING || status === WORK_STATUS.REWORKING) {
    patch.activityState = ACTIVITY_STATE.CODEX_RUNNING;
  }
  if (status === WORK_STATUS.RESULT_VALIDATION_RETRYING) {
    patch.activityState = ACTIVITY_STATE.VALIDATION_RETRY_WAITING;
  }
  if (status === WORK_STATUS.WAITING_APPROVAL) {
    patch.activityState = ACTIVITY_STATE.APPROVAL_PREPARING;
  }
  if (interruptionStatus.has(status) && status !== WORK_STATUS.RESULT_VALIDATION_RETRYING) {
    patch.activityState = status;
    patch.errorMessage = String(body.summary || status).slice(0, 2000);
  }
  if (reportsCompletion && !previous.completedAt) patch.completedAt = ts;

  const jobPatch = {
    currentStage: stageId,
    currentStageNumber: Number(body.stageNumber || previous.stageNumber) ||
      stageDefinition?.order || 0,
    updatedAt: ts,
    lastActivityAt: ts,
    ...(body.criteriaMet != null ? { currentStageCriteriaMet: body.criteriaMet === true } : {}),
    ...(body.approvalRequired != null ? { approvalRequired: body.approvalRequired === true } : {}),
    ...(patch.attemptCount != null ? { attemptCount: patch.attemptCount } : {}),
    ...(patch.maxAttempts != null ? { maxAttempts: patch.maxAttempts } : {}),
    ...(patch.retryCount != null ? { retryCount: patch.retryCount } : {}),
    ...(patch.maxRetries != null ? { maxRetries: patch.maxRetries } : {}),
    ...(patch.nextRetryAt != null ? { nextRetryAt: patch.nextRetryAt } : {}),
    ...(patch.retryable != null ? { retryable: patch.retryable } : {}),
  };
  // An approval gate belongs to the job as well as the stage. Persist both in
  // one transaction so a successful report-stage can never leave job=running.
  if (status === WORK_STATUS.WAITING_APPROVAL) {
    jobPatch.status = WORK_STATUS.WAITING_APPROVAL;
  } else if (activeStatus.has(status)) {
    jobPatch.status = status === WORK_STATUS.REWORKING
      ? WORK_STATUS.REWORKING
      : WORK_STATUS.RUNNING;
  } else if (status === WORK_STATUS.COMPLETED) {
    jobPatch.status = (stageDefinition?.terminal ||
      stageDefinition?.productionBoundary)
      ? WORK_STATUS.COMPLETED
      : WORK_STATUS.RUNNING;
  } else if (status === WORK_STATUS.RESULT_VALIDATION_RETRYING) {
    jobPatch.status = status;
  } else if (interruptionStatus.has(status)) {
    jobPatch.status = status;
    jobPatch.pauseReason = status;
  }
  const instructionId = String(job.instructionId || "").trim();
  const projectRef = instructionId
    ? db.collection(COL.PROJECTS).doc(instructionId)
    : null;
  const projectStageRef = projectRef
    ? projectRef.collection("stages").doc(stageId)
    : null;
  await db.runTransaction(async (tx) => {
    const snapshots = await Promise.all([
      tx.get(jobRef),
      tx.get(stageRef),
      ...(projectRef ? [tx.get(projectRef), tx.get(projectStageRef)] : []),
    ]);
    const currentJob = snapshots[0].exists ? snapshots[0].data() || {} : {};
    const currentJobStage = snapshots[1].exists
      ? snapshots[1].data() || {}
      : {};
    const resumesRecovery = activeStatus.has(status) && currentJobStage.recoveryState === "safe_stopped" &&
      Number(body.revision) === Number(currentJobStage.revision);
    const reportedPatch = { ...patch, ...(resumesRecovery ? { recoveryState: "resumed" } : {}) };
    const reportedJobPatch = { ...jobPatch, ...(resumesRecovery ? { recoveryState: "resumed" } : {}) };
    const safeJobStage = mergeMonotonicStage(currentJobStage, reportedPatch);
    const safeJob = mergeMonotonicProject(currentJob, reportedJobPatch);
    tx.set(stageRef, safeJobStage, { merge: true });
    tx.set(jobRef, safeJob, { merge: true });
    if (projectRef && snapshots[2].exists) {
      const currentProject = snapshots[2].data() || {};
      const currentProjectStage = snapshots[3].exists
        ? snapshots[3].data() || {}
        : {};
      const projectStagePatch = mergeMonotonicStage(currentProjectStage, {
        ...reportedPatch,
        status: toProjectStageStatus(status),
        activityState: patch.activityState || String(previous.activityState || ""),
      });
      tx.set(projectStageRef, projectStagePatch, { merge: true });
      const projectStatus = projectStagePatch.status === "awaiting_approval"
        ? "awaiting_approval"
        : interruptionStatus.has(projectStagePatch.status)
          ? projectStagePatch.status
        : (stageDefinition?.terminal ||
            stageDefinition?.productionBoundary) &&
            projectStagePatch.status === "completed"
          ? "completed"
          : "in_progress";
      const safeProject = mergeMonotonicProject(currentProject, {
        currentStage: Number(projectStagePatch.stageNumber) ||
          stageDefinition?.order || 0,
        currentStageId: stageId,
        status: projectStatus,
        lastActivityAt: ts,
        activityState: projectStagePatch.activityState || "",
        approvalMode: job.approvalMode === "auto" ? "auto" : "manual",
        updatedAt: ts,
        ...(resumesRecovery ? { recoveryState: "resumed" } : {}),
        ...(projectStagePatch.attemptCount != null
          ? { attemptCount: projectStagePatch.attemptCount } : {}),
        ...(projectStagePatch.maxAttempts != null
          ? { maxAttempts: projectStagePatch.maxAttempts } : {}),
        ...(projectStagePatch.retryCount != null
          ? { retryCount: projectStagePatch.retryCount } : {}),
        ...(projectStagePatch.maxRetries != null
          ? { maxRetries: projectStagePatch.maxRetries } : {}),
        ...(projectStagePatch.nextRetryAt != null
          ? { nextRetryAt: projectStagePatch.nextRetryAt } : {}),
        ...(projectStagePatch.retryable != null
          ? { retryable: projectStagePatch.retryable } : {}),
        ...(projectStagePatch.status === "awaiting_approval"
          ? { approvalStatus: "pending" }
          : {}),
      });
      tx.set(projectRef, safeProject, { merge: true });
    }
  });
  if (status === WORK_STATUS.COMPLETED &&
      stageDefinition?.productionBoundary === true &&
      stageDefinition.order === 18) {
    await queueNotificationSafely(db, {
      ownerUid: job.ownerUid || ctx.agent.ownerUid || "",
      instructionId: job.instructionId || "",
      jobId,
      stageId,
      stageNumber: 18,
      stageName: String(body.stageName || previous.stageName || stageDefinition.name),
      revision: Math.max(1, Number(body.revision || previous.revision) || 1),
      eventType: "production_completed",
      productType,
      severity: "info",
      actionRequired: false,
    });
  }
  if (status === WORK_STATUS.WAITING_APPROVAL && job.approvalMode !== "auto") {
    const revision = Math.max(1, Number(body.revision || previous.revision) || 1);
    await queueNotificationSafely(db, {
      ownerUid: job.ownerUid || ctx.agent.ownerUid || "",
      instructionId: job.instructionId || "",
      jobId,
      stageId,
      stageNumber: Number(body.stageNumber || previous.stageNumber) || 0,
      stageName: String(body.stageName || previous.stageName || stageId),
      revision,
      eventType: revision > 1 ? "revision_completed" : "approval_required",
      severity: "warning",
      actionRequired: true,
    });
  }
  return {};
}

async function handleReportActivity(db, ctx, body) {
  const jobId = String(body.jobId || ctx.agent.currentJobId || "").trim();
  const stageId = String(body.stageId || "").trim();
  const activityState = String(body.activityState || "").trim();
  const activityType = String(body.activityType || "").trim();
  if (!jobId || !stageId) {
    throw httpError(400, "invalid_payload", "jobId_and_stageId required");
  }
  if (!ACTIVITY_STATES.has(activityState) || !ACTIVITY_TYPES.has(activityType)) {
    throw httpError(400, "invalid_payload", "activity invalid");
  }
  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const stageRef = jobRef.collection("stages").doc(stageId);
  const [jobSnap, stageSnap] = await Promise.all([jobRef.get(), stageRef.get()]);
  if (!jobSnap.exists) throw httpError(404, "not_found", "job_missing");
  const job = jobSnap.data() || {};
  if (job.assignedAgentId && job.assignedAgentId !== ctx.agentId) {
    throw httpError(403, "forbidden", "agent_mismatch");
  }
  const previous = stageSnap.exists ? stageSnap.data() || {} : {};
  const ts = nowIso();
  const stagePatch = {
    stageId,
    stageNumber: Number(body.stageNumber || previous.stageNumber) || 0,
    lastActivityAt: ts,
    activityState,
    activityType,
    revision: Math.max(1, Number(body.revision || previous.revision) || 1),
    updatedAt: ts,
  };
  if (activityState.startsWith("codex_")) {
    stagePatch.executorKind = "codex";
  } else if (activityState.startsWith("cursor_")) {
    stagePatch.executorKind = "cursor";
  }
  if (!previous.startedAt) stagePatch.startedAt = ts;
  if (body.progress != null) {
    stagePatch.activityProgress = Math.max(0, Math.min(100, Number(body.progress) || 0));
  }
  for (const field of ["attemptCount", "maxAttempts", "retryCount", "maxRetries"]) {
    if (body[field] != null) stagePatch[field] = Math.max(0, Number(body[field]) || 0);
  }
  if (body.nextRetryAt != null) stagePatch.nextRetryAt = String(body.nextRetryAt).slice(0, 80);
  if (body.failureReason != null) stagePatch.failureReason = String(body.failureReason).slice(0, 240);
  if (body.failureType != null) stagePatch.failureType = String(body.failureType).slice(0, 40);
  if (body.retryable != null) stagePatch.retryable = body.retryable === true;
  await db.runTransaction(async (tx) => {
    await tx.set(stageRef, stagePatch, { merge: true });
    await tx.set(jobRef, {
      currentStage: stageId,
      currentStageNumber: stagePatch.stageNumber,
      lastActivityAt: ts,
      activityState,
      updatedAt: ts,
    }, { merge: true });
  });
  await mirrorMonitoring(
    db,
    String(body.instructionId || job.instructionId || "").trim(),
    stageId,
    stagePatch,
    {
      lastActivityAt: ts,
      activityState,
      ...(stagePatch.executorKind
        ? { currentWorker: stagePatch.executorKind }
        : {}),
      updatedAt: ts,
    }
  );
  return { lastActivityAt: ts };
}

async function handleReportError(db, ctx, body) {
  const code = String(body.code || "error").slice(0, 120);
  const message = String(body.message || "").slice(0, 500);
  const jobId = String(body.jobId || ctx.agent.currentJobId || "").trim();
  const ts = nowIso();
  const eventId = newId("evt");

  if (jobId) {
    const jobRef = db.collection(COL.JOBS).doc(jobId);
    const jobSnap = await jobRef.get();
    if (jobSnap.exists) {
      const job = jobSnap.data() || {};
      if (job.assignedAgentId && job.assignedAgentId !== ctx.agentId) {
        throw httpError(403, "forbidden", "agent_mismatch");
      }
      await jobRef.collection("events").doc(eventId).set({
        eventId,
        type: "error",
        agentId: ctx.agentId,
        ownerUid: job.ownerUid || ctx.agent.ownerUid || "",
        code,
        message,
        createdAt: ts,
      });
      await queueNotificationSafely(db, {
        ownerUid: job.ownerUid || ctx.agent.ownerUid || "",
        instructionId: body.instructionId || job.instructionId || "",
        jobId,
        stageId: body.stageId || job.currentStage || "",
        stageNumber: body.stageNumber || job.currentStageNumber || 0,
        stageName: body.stageName || "AI 제작 단계",
        revision: body.revision || 1,
        eventType: "work_error",
        severity: "critical",
        actionRequired: true,
      });
    }
  }

  await ctx.agentRef.set(
    {
      state: AGENT_STATE.ERROR,
      updatedAt: ts,
      lastError: { code, message, at: ts },
    },
    { merge: true }
  );
  return {};
}

/** Control: create pairing session — returns plaintext code once */
async function handleCreatePairing(db, uid, body = {}) {
  const sessionId = newId("pair");
  const pairingCode = randomPairingCode();
  const codeHash = sha256Hex(pairingCode);
  const ts = nowIso();
  const expiresAt = new Date(Date.now() + PAIRING_TTL_MS).toISOString();

  await db.collection(COL.PAIRING).doc(sessionId).set({
    sessionId,
    ownerUid: uid,
    codeHash,
    createdAt: ts,
    expiresAt,
    used: false,
    usedAt: null,
    agentId: null,
    updatedAt: ts,
  });

  return {
    sessionId,
    pairingCode,
    expiresAt,
    ttlSeconds: Math.floor(PAIRING_TTL_MS / 1000),
  };
}

async function handleRegisterNotificationToken(db, uid, body = {}) {
  const token = String(body.token || "").trim();
  const platform = String(body.platform || "web").trim().slice(0, 20);
  const deviceId = String(body.deviceId || "").trim();
  if (token.length < 20 || token.length > 4096) {
    throw httpError(400, "invalid_payload", "token invalid");
  }
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(deviceId)) {
    throw httpError(400, "invalid_payload", "deviceId invalid");
  }
  const tokenId = sha256Hex(`${uid}|${deviceId}`);
  const ts = nowIso();
  const ref = db.collection(COL.USERS).doc(uid).collection("notificationTokens").doc(tokenId);
  const existing = await ref.get();
  await ref.set({
    token,
    deviceId,
    platform,
    enabled: true,
    updatedAt: ts,
    ...(existing.exists ? {} : { createdAt: ts }),
  }, { merge: true });
  return { tokenId, deviceId };
}

async function handleUnregisterNotificationToken(db, uid, body = {}) {
  const deviceId = String(body.deviceId || "").trim();
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(deviceId)) {
    throw httpError(400, "invalid_payload", "deviceId invalid");
  }
  const tokenId = sha256Hex(`${uid}|${deviceId}`);
  await db.collection(COL.USERS).doc(uid)
    .collection("notificationTokens").doc(tokenId).delete();
  return { tokenId, removed: true };
}

async function handleNotificationDiagnostics(db, uid) {
  const policy = await loadPolicy(db);
  const [tokensSnap, eventsSnap] = await Promise.all([
    db.collection(COL.USERS).doc(uid).collection("notificationTokens").get(),
    db.collection(COL.NOTIFICATION_EVENTS).where("ownerUid", "==", uid).limit(100).get(),
  ]);
  const devices = tokensSnap.docs
    .map((doc) => {
      const data = doc.data() || {};
      return {
        tokenId: doc.id,
        deviceId: String(data.deviceId || ""),
        platform: String(data.platform || "unknown"),
        enabled: data.enabled !== false && Boolean(data.token),
        updatedAt: String(data.updatedAt || ""),
      };
    })
    .filter((item) => item.enabled);
  const history = eventsSnap.docs
    .map((doc) => {
      const data = doc.data() || {};
      return {
        notificationEventId: String(data.notificationEventId || doc.id),
        eventType: String(data.eventType || ""),
        title: String(data.title || ""),
        body: String(data.body || ""),
        status: String(data.status || ""),
        createdAt: String(data.createdAt || ""),
        deepLink: String(data.deepLink || ""),
      };
    })
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, 20);
  return {
    deliveryMode: policy.notificationDeliveryMode,
    environment: policy.environment,
    registeredDeviceCount: devices.length,
    devices,
    recentNotifications: history,
  };
}

async function handleSendTestNotification(db, uid) {
  const policy = await loadPolicy(db);
  const out = await enqueueNotification(db, {
    ownerUid: uid,
    eventType: "test_notification",
    revision: 1,
    severity: "info",
    actionRequired: false,
    source: "notification_diagnostics",
    idempotencyDiscriminator: newId("test"),
  }, policy);
  return {
    notificationEventId: out.id,
    deliveryMode: policy.notificationDeliveryMode,
    queued: out.created,
  };
}

async function handleCreateJob(db, uid, body) {
  const title = String(body.title || "Untitled").trim().slice(0, 200);
  const type = String(body.type || "ebook").trim().slice(0, 64);
  const assignedAgentId = String(body.assignedAgentId || "").trim();
  if (!assignedAgentId) throw httpError(400, "invalid_payload", "assignedAgentId required");

  const agentSnap = await db.collection(COL.AGENTS).doc(assignedAgentId).get();
  if (!agentSnap.exists) throw httpError(404, "not_found", "agent_missing");
  const agent = agentSnap.data() || {};
  if (agent.ownerUid !== uid) throw httpError(403, "forbidden", "agent_owner_mismatch");

  const instructionId = String(body.instructionId || "").trim();
	const inferredTest = instructionId.startsWith("wi_test_") ||
	  instructionId.includes("e2e") || /^\[test\]/i.test(title);
	const isTest = body.isTest === true || inferredTest;
	const environment = isTest ? "test" : "production";
	if (body.environment && String(body.environment) !== environment) {
	  throw httpError(400, "invalid_payload", "environment_isTest_mismatch");
	}
	if (body.isTest === false && inferredTest) {
	  throw httpError(400, "invalid_payload", "test_marker_isTest_mismatch");
	}
  if (instructionId) {
    const existing = await findJobByInstructionId(db, uid, instructionId);
    if (existing) {
      return { jobId: existing.id, idempotent: true };
    }
  }

  const jobId = newId("job");
  const ts = nowIso();
  const totalStages = Number(body.totalStages) || 18;
  const payload = isPlainObject(body.payload) ? body.payload : {};
  const aiExecution = isPlainObject(payload.aiExecution) ? payload.aiExecution : {};
  const approvalMode = String(body.approvalMode || payload.approvalMode ||
    aiExecution.approvalMode || "manual") === "auto" ? "auto" : "manual";
  const doc = {
    jobId,
    ownerUid: uid,
    type,
    productType: type,
    title,
    status: WORK_STATUS.QUEUED,
    assignedAgentId,
    currentStage: "",
    totalStages,
    progress: 0,
    createdAt: ts,
    startedAt: null,
    completedAt: null,
    updatedAt: ts,
	  environment,
	  isTest,
    approvalMode,
  };
  if (instructionId) doc.instructionId = instructionId;
  await db.collection(COL.JOBS).doc(jobId).set(doc);
  return { jobId, idempotent: false };
}

async function findJobByInstructionId(db, uid, instructionId) {
  const snap = await db
    .collection(COL.JOBS)
    .where("ownerUid", "==", uid)
    .orderBy("updatedAt", "desc")
    .limit(80)
    .get();
  for (const d of snap.docs) {
    const data = d.data() || {};
    if (String(data.instructionId || "").trim() === instructionId) {
      return { id: d.id, data };
    }
  }
  return null;
}

async function findStartCommand(jobRef) {
  const all = await jobRef.collection("commands").get();
  for (const d of all.docs) {
    const data = d.data() || {};
    if (data.type === COMMAND_TYPE.START_JOB && data.commandId) {
      return data;
    }
  }
  return null;
}

async function handleStartJob(db, uid, body) {
  const jobId = String(body.jobId || "").trim();
  if (!jobId) throw httpError(400, "invalid_payload", "jobId required");

  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) throw httpError(404, "not_found", "job_missing");
  const job = jobSnap.data() || {};
  if (job.ownerUid !== uid) throw httpError(403, "forbidden", "job_owner_mismatch");
  if (!job.assignedAgentId) throw httpError(400, "invalid_payload", "assignedAgentId missing");

  const existingStart = await findStartCommand(jobRef);
  if (existingStart) {
    return { commandId: existingStart.commandId, jobId, idempotent: true };
  }

  const commandId = newId("cmd");
  const idempotencyKey = String(body.idempotencyKey || `idem_${commandId}`);
  const payload = isPlainObject(body.payload) ? body.payload : {};
  const ts = nowIso();

  const existing = await jobRef
    .collection("commands")
    .where("idempotencyKey", "==", idempotencyKey)
    .limit(1)
    .get();
  if (!existing.empty) {
    const d = existing.docs[0].data();
    return { commandId: d.commandId, jobId, idempotent: true };
  }

  const cmd = {
    commandId,
    jobId,
    agentId: job.assignedAgentId,
    ownerUid: uid,
    type: COMMAND_TYPE.START_JOB,
    status: COMMAND_STATUS.QUEUED,
    idempotencyKey,
    payload,
    createdAt: ts,
    claimedAt: null,
    completedAt: null,
    failedAt: null,
    error: null,
    attempt: 0,
    updatedAt: ts,
  };
  await jobRef.collection("commands").doc(commandId).set(cmd);
  await jobRef.set({ status: WORK_STATUS.QUEUED, updatedAt: ts }, { merge: true });
  return { commandId, jobId, idempotent: false };
}

async function resolveOnlineAgent(db, uid, assignedAgentId) {
  if (assignedAgentId) {
    const snap = await db.collection(COL.AGENTS).doc(assignedAgentId).get();
    if (!snap.exists) throw httpError(404, "not_found", "agent_missing");
    const agent = snap.data() || {};
    if (agent.ownerUid !== uid) throw httpError(403, "forbidden", "agent_owner_mismatch");
    if (agent.enabled === false) {
      throw httpError(409, "agent_offline", "agent disabled");
    }
    if (!isAgentOnline(agent.lastHeartbeatAt)) {
      throw httpError(409, "agent_offline", "agent offline");
    }
    return assignedAgentId;
  }
  const snap = await db.collection(COL.AGENTS).where("ownerUid", "==", uid).get();
  const online = [];
  for (const d of snap.docs) {
    const a = d.data() || {};
    if (a.enabled === false) continue;
    if (!isAgentOnline(a.lastHeartbeatAt)) continue;
    online.push({ id: d.id, agentId: a.agentId || d.id, deviceName: a.deviceName || "" });
  }
  if (online.length === 0) {
    throw httpError(409, "agent_offline", "no online agent");
  }
  const jt = online.find((a) => String(a.deviceName).toUpperCase().includes("JT-JEON"));
  return (jt || online[0]).agentId;
}

async function handleDeliverInstruction(db, uid, body) {
  const instructionId = String(body.instructionId || "").trim();
  if (!instructionId) throw httpError(400, "invalid_payload", "instructionId required");
  const payload = isPlainObject(body.payload) ? body.payload : {};
  const payloadId = String(payload.instructionId || "").trim();
  if (payloadId && payloadId !== instructionId) {
    throw httpError(400, "invalid_payload", "instructionId mismatch");
  }

  const assignedAgentId = await resolveOnlineAgent(
    db,
    uid,
    String(body.assignedAgentId || "").trim()
  );

  const existing = await findJobByInstructionId(db, uid, instructionId);
  const inFlight = new Set([
    WORK_STATUS.CLAIMED,
    WORK_STATUS.RUNNING,
    WORK_STATUS.WAITING_APPROVAL,
    WORK_STATUS.REVISION_REQUESTED,
    WORK_STATUS.REWORKING,
  ]);

  if (existing) {
    const jobId = existing.id;
    const status = existing.data.status;
    const jobRef = db.collection(COL.JOBS).doc(jobId);
    const start = await findStartCommand(jobRef);
    if (start) {
      let outcome = "reused";
      if (inFlight.has(status)) outcome = "reused_in_progress";
      if (status === WORK_STATUS.COMPLETED || status === WORK_STATUS.APPROVED) {
        outcome = "reused_completed";
      }
      return {
        jobId,
        commandId: start.commandId,
        agentId: existing.data.assignedAgentId,
        outcome,
        idempotent: true,
      };
    }
    if (status === WORK_STATUS.COMPLETED || status === WORK_STATUS.APPROVED) {
      throw httpError(409, "already_completed", "job already completed");
    }
    if (inFlight.has(status)) {
      throw httpError(409, "already_in_progress", "job already claimed");
    }
    const started = await handleStartJob(db, uid, {
      jobId,
      payload,
      idempotencyKey: `idem_start_${instructionId}`,
    });
    return {
      jobId,
      commandId: started.commandId,
      agentId: existing.data.assignedAgentId,
      outcome: "command_repaired",
      idempotent: started.idempotent === true,
    };
  }

  const created = await handleCreateJob(db, uid, {
    ...body,
    assignedAgentId,
    instructionId,
    payload,
  });
  const started = await handleStartJob(db, uid, {
    jobId: created.jobId,
    payload,
    idempotencyKey: `idem_start_${instructionId}`,
  });
  return {
    jobId: created.jobId,
    commandId: started.commandId,
    agentId: assignedAgentId,
    outcome: "created",
    idempotent: false,
  };
}

/** Stubs for approve/revision validators (contract ready) */
function validateApproveStageBody(body) {
  if (!String(body.jobId || "").trim()) throw httpError(400, "invalid_payload", "jobId required");
  if (!String(body.stageId || "").trim()) throw httpError(400, "invalid_payload", "stageId required");
}

function validateRequestRevisionBody(body) {
  validateApproveStageBody(body);
  if (!String(body.message || "").trim()) {
    throw httpError(400, "invalid_payload", "message required");
  }
}

function isAgentOnline(lastHeartbeatAt, now = Date.now()) {
  if (!lastHeartbeatAt) return false;
  const t = typeof lastHeartbeatAt === "string"
    ? Date.parse(lastHeartbeatAt)
    : lastHeartbeatAt.toMillis
      ? lastHeartbeatAt.toMillis()
      : Number(lastHeartbeatAt);
  if (!Number.isFinite(t)) return false;
  return now - t <= ONLINE_WITHIN_MS;
}

module.exports = {
  handleEnroll,
  handleHeartbeat,
  handlePull,
  handleClaim,
  handleComplete,
  handleFail,
  handleReportState,
  handleReportJob,
  handleReportStage,
  handleReportActivity,
  handleReportError,
  handleCreatePairing,
  handleRegisterNotificationToken,
  handleUnregisterNotificationToken,
  handleNotificationDiagnostics,
  handleSendTestNotification,
  handleCreateJob,
  handleStartJob,
  handleDeliverInstruction,
  handleCancelJob,
  validateApproveStageBody,
  validateRequestRevisionBody,
  isAgentOnline,
  sendOk,
  applyProductionReviewStatus,
};
