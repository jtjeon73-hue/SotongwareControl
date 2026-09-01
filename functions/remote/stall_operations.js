"use strict";

const { sha256Hex } = require("./crypto_util");
const { COL, WORK_STATUS, COMMAND_TYPE, COMMAND_STATUS } = require("./constants");
const { httpError } = require("./http");
const { nowIso } = require("./log");
const {
  buildStallDiagnostic,
  evaluateStageHealth,
  loadPolicy,
  isRecoveryImportOnly,
} = require("./monitoring");
const { handleCancelJob } = require("./cancellation");

const MANUAL_RECOVERY_OPS = "manualRecoveryOperations";

function text(value, max = 180) {
  return String(value || "").trim().slice(0, max);
}

function operationId(uid, jobId, stageId, action) {
  return `${action}_${sha256Hex(`${uid}|${jobId}|${stageId}|${action}`).slice(0, 32)}`;
}

async function loadOwnedJob(db, uid, jobId, instructionId) {
  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) throw httpError(404, "not_found", "job_missing");
  const job = jobSnap.data() || {};
  if (String(job.ownerUid || "") !== uid) throw httpError(403, "forbidden", "job_owner_mismatch");
  if (instructionId && String(job.instructionId || "") !== instructionId) {
    throw httpError(409, "run_mismatch", "job_instruction_mismatch");
  }
  return { jobRef, job };
}

async function handleRecheckStatus(db, uid, body) {
  const jobId = text(body.jobId, 128);
  const instructionId = text(body.instructionId, 128);
  const projectId = text(body.projectId || instructionId, 128);
  const stageId = text(body.stageId, 128);
  if (!jobId || !instructionId || !projectId) {
    throw httpError(400, "invalid_payload", "jobId/instructionId/projectId required");
  }
  const { jobRef, job } = await loadOwnedJob(db, uid, jobId, instructionId);
  const currentStage = stageId || String(job.currentStage || "");
  const [agentSnap, stageSnap, projectSnap] = await Promise.all([
    job.assignedAgentId
      ? db.collection(COL.AGENTS).doc(job.assignedAgentId).get()
      : Promise.resolve(null),
    currentStage ? jobRef.collection("stages").doc(currentStage).get() : Promise.resolve(null),
    db.collection(COL.PROJECTS).doc(projectId).get(),
  ]);
  const stage = stageSnap && stageSnap.exists ? stageSnap.data() || {} : {};
  const agent = agentSnap && agentSnap.exists ? agentSnap.data() || {} : {};
  const project = projectSnap.exists ? projectSnap.data() || {} : {};
  const policy = await loadPolicy(db);
  const health = evaluateStageHealth({
    job, stage, agent, policy, nowMs: Date.now(),
  });
  const diagnostic = buildStallDiagnostic({ job, stage, agent, health, nowMs: Date.now() });
  let cancelDiagnostic = null;
  const opId = text(project.cancelOperationId || job.cancelOperationId, 128);
  if (opId) {
    const diagSnap = await db.collection("cancelDiagnostics").doc(opId).get();
    if (diagSnap.exists) cancelDiagnostic = diagSnap.data() || null;
  }
  return {
    state: "ok",
    jobId,
    instructionId,
    projectId,
    stageId: currentStage,
    revision: Number(stage.revision) || 1,
    effectiveWorker: diagnostic.effectiveWorker,
    workerPid: diagnostic.workerPid,
    handoffSessionId: diagnostic.handoffSessionId,
    agentState: String(agent.state || ""),
    relayHealthy: agent.enabled !== false,
    heartbeatAt: String(agent.lastHeartbeatAt || ""),
    lastActivityAt: diagnostic.lastActivityAt,
    recoveryAttempt: diagnostic.recoveryAttempt,
    maxRecoveryAttempts: diagnostic.maxRecoveryAttempts,
    recoveryState: diagnostic.recoveryState,
    failureReason: diagnostic.failureReason,
    recommendedAction: diagnostic.recommendedAction,
    dispatchBlocked: Boolean(job.dispatchBlocked || stage.dispatchBlocked || project.dispatchBlocked),
    health: health.state,
    cancelDiagnostic,
    checkedAt: nowIso(),
  };
}

async function handlePauseJob(db, uid, body) {
  const jobId = text(body.jobId, 128);
  const instructionId = text(body.instructionId, 128);
  const projectId = text(body.projectId || instructionId, 128);
  const stageId = text(body.stageId, 128);
  if (!jobId || !instructionId || !projectId) {
    throw httpError(400, "invalid_payload", "jobId/instructionId/projectId required");
  }
  const opId = operationId(uid, jobId, stageId || "stage", "safe_pause");
  const opRef = db.collection("safePauseOperations").doc(opId);
  const existing = await opRef.get();
  if (existing.exists && existing.data().status === "completed") {
    return { state: "paused", idempotent: true, operationId: opId };
  }
  const { jobRef, job } = await loadOwnedJob(db, uid, jobId, instructionId);
  const currentStage = stageId || String(job.currentStage || "");
  const ts = nowIso();
  const patch = {
    status: WORK_STATUS.PAUSED,
    activityState: "safe_stopped",
    recoveryState: "safe_stopped",
    pauseReason: "operator_safe_pause",
    dispatchBlocked: true,
    autoRecoveryDisabled: true,
    updatedAt: ts,
  };
  await jobRef.set(patch, { merge: true });
  if (currentStage) {
    await jobRef.collection("stages").doc(currentStage).set(patch, { merge: true });
  }
  const projectRef = db.collection(COL.PROJECTS).doc(projectId);
  await projectRef.set(patch, { merge: true });
  if (currentStage) {
    await projectRef.collection("stages").doc(currentStage).set(patch, { merge: true });
    const requestId = `safe_pause_${opId.slice("safe_pause_".length)}`;
    await projectRef.collection("requests").doc(requestId).set({
      requestId,
      safePauseOperationId: opId,
      ownerUid: uid,
      jobId,
      projectId,
      stageId: currentStage,
      requestType: "safe_pause",
      status: "pending",
      message: text(body.message || "운영자 안전 일시정지", 500),
      processed: false,
      workflowApplied: false,
      createdAt: ts,
      updatedAt: ts,
    }, { merge: true });
  }
  if (job.assignedAgentId) {
    const pauseCommandId = `cmd_pause_${sha256Hex(`${jobId}:${currentStage}:${opId}`).slice(0, 24)}`;
    await jobRef.collection("commands").doc(pauseCommandId).set({
      commandId: pauseCommandId,
      idempotencyKey: `safe_pause:${jobId}:${currentStage}`,
      agentId: job.assignedAgentId,
      jobId,
      type: COMMAND_TYPE.PAUSE_JOB,
      status: COMMAND_STATUS.QUEUED,
      payload: { instructionId, stageId: currentStage, projectId, operationId: opId },
      createdAt: ts,
      updatedAt: ts,
    }, { merge: true });
  }
  await opRef.set({
    operationId: opId,
    ownerUid: uid,
    jobId,
    instructionId,
    projectId,
    stageId: currentStage,
    status: "completed",
    completedAt: ts,
    updatedAt: ts,
  }, { merge: true });
  return { state: "paused", operationId: opId, idempotent: false };
}

async function handleRecoveryOnce(db, uid, body) {
  const jobId = text(body.jobId, 128);
  const instructionId = text(body.instructionId, 128);
  const stageId = text(body.stageId, 128);
  if (!jobId || !instructionId || !stageId) {
    throw httpError(400, "invalid_payload", "jobId/instructionId/stageId required");
  }
  const opId = operationId(uid, jobId, stageId, "manual_recovery");
  const opRef = db.collection(MANUAL_RECOVERY_OPS).doc(opId);
  const { jobRef, job } = await loadOwnedJob(db, uid, jobId, instructionId);
  if (job.dispatchBlocked || job.recoveryState === "safe_stopped") {
    throw httpError(409, "paused", "job is safely paused");
  }
  const existing = await opRef.get();
  if (existing.exists) {
    const prior = existing.data() || {};
    return {
      state: prior.resultState || "recovery_requested",
      idempotent: true,
      operationId: opId,
      recoveryCommandId: prior.recoveryCommandId || "",
      result: prior.result || "already_requested",
    };
  }
  const stageRef = jobRef.collection("stages").doc(stageId);
  const stageSnap = await stageRef.get();
  if (!stageSnap.exists) throw httpError(404, "not_found", "stage_missing");
  const stage = stageSnap.data() || {};
  if (stage.manualRecoveryUsed) {
    return {
      state: "recovery_exhausted",
      idempotent: true,
      operationId: opId,
      result: "manual_recovery_already_used",
    };
  }
  if (isRecoveryImportOnly(stage)) {
    throw httpError(409, "recovery_import_only", "previous recovery imported without handoff binding");
  }
  const commands = await jobRef.collection("commands").get();
  const original = commands.docs
    .map((item) => item.data() || {})
    .find((item) => item.type === COMMAND_TYPE.START_JOB && item.payload);
  if (!original) throw httpError(409, "recovery_unavailable", "START_JOB payload missing");
  const ts = nowIso();
  const recoveryCommandId = `cmd_manual_recovery_${sha256Hex(`${jobId}:${stageId}:${opId}`).slice(0, 20)}`;
  const originalAiExecution = original.payload.aiExecution || {};
  const originalWorker = String(originalAiExecution.worker || "").toLowerCase();
  const selectedWorker = originalWorker === "codex" ? "cursor" : (originalWorker || "cursor");
  await jobRef.collection("commands").doc(recoveryCommandId).set({
    commandId: recoveryCommandId,
    idempotencyKey: `manual_once:${jobId}:${stageId}`,
    agentId: job.assignedAgentId,
    jobId,
    type: COMMAND_TYPE.START_JOB,
    status: COMMAND_STATUS.QUEUED,
    attempt: 0,
    payload: {
      ...original.payload,
      aiExecution: { ...originalAiExecution, worker: selectedWorker },
      recovery: {
        stageId,
        attempt: 1,
        maxAttempts: 1,
        action: "manual_operator_recovery_once",
        previousWorker: originalWorker,
        selectedWorker,
        manual: true,
      },
    },
    createdAt: ts,
    updatedAt: ts,
  }, { merge: true });
  const patch = {
    manualRecoveryUsed: true,
    manualRecoveryCommandId: recoveryCommandId,
    manualRecoveryAt: ts,
    autoRecoveryDisabled: true,
    recoveryState: "requested",
    recoveryCommandId,
    updatedAt: ts,
  };
  await stageRef.set(patch, { merge: true });
  await jobRef.set(patch, { merge: true });
  if (job.instructionId) {
    const projectRef = db.collection(COL.PROJECTS).doc(job.instructionId);
    await projectRef.collection("stages").doc(stageId).set(patch, { merge: true });
    await projectRef.set({ ...patch, pauseReason: WORK_STATUS.STALLED }, { merge: true });
  }
  await opRef.set({
    operationId: opId,
    ownerUid: uid,
    jobId,
    instructionId,
    stageId,
    recoveryCommandId,
    resultState: "recovery_requested",
    result: "queued",
    status: "completed",
    completedAt: ts,
    updatedAt: ts,
  }, { merge: true });
  return {
    state: "recovery_requested",
    idempotent: false,
    operationId: opId,
    recoveryCommandId,
    selectedWorker,
  };
}

async function handleGetDiagnostics(db, uid, body) {
  const instructionId = text(body.instructionId, 128);
  const operationIdValue = text(body.operationId, 128);
  if (!instructionId && !operationIdValue) {
    throw httpError(400, "invalid_payload", "instructionId or operationId required");
  }
  if (operationIdValue) {
    const snap = await db.collection("cancelDiagnostics").doc(operationIdValue).get();
    if (!snap.exists) throw httpError(404, "not_found", "diagnostic_missing");
    const data = snap.data() || {};
    if (String(data.ownerUid || "") !== uid) throw httpError(403, "forbidden", "owner_mismatch");
    return { state: "ok", diagnostic: data };
  }
  const snap = await db.collection("cancelDiagnostics")
    .where("instructionId", "==", instructionId)
    .limit(5)
    .get();
  const items = snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }));
  return { state: "ok", diagnostics: items };
}

module.exports = {
  handleRecheckStatus,
  handlePauseJob,
  handleRecoveryOnce,
  handleGetDiagnostics,
  handleCancelJob,
};
