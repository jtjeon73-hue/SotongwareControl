"use strict";

const { sha256Hex } = require("./crypto_util");
const {
  COL,
  WORK_STATUS,
  COMMAND_TYPE,
  COMMAND_STATUS,
} = require("./constants");

const DEFAULT_POLICY = Object.freeze({
  onlineWithinSeconds: 120,
  offlineAfterSeconds: 600,
  noActivityAfterSeconds: 900,
  defaultExpectedMinSeconds: 180,
  defaultExpectedMaxSeconds: 480,
  minimumDurationSamples: 5,
  notificationDeliveryMode: "outbox_only",
  environment: "production",
  controlBaseUrl: "https://sotongware-control.web.app",
  stageExpectedDurations: {},
});

function finitePositive(value, fallback) {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

function normalizePolicy(raw = {}) {
  const mode = raw.notificationDeliveryMode === "fcm" ? "fcm" : "outbox_only";
  return {
    onlineWithinSeconds: finitePositive(raw.onlineWithinSeconds, DEFAULT_POLICY.onlineWithinSeconds),
    offlineAfterSeconds: finitePositive(raw.offlineAfterSeconds, DEFAULT_POLICY.offlineAfterSeconds),
    noActivityAfterSeconds: finitePositive(raw.noActivityAfterSeconds, DEFAULT_POLICY.noActivityAfterSeconds),
    defaultExpectedMinSeconds: finitePositive(raw.defaultExpectedMinSeconds, DEFAULT_POLICY.defaultExpectedMinSeconds),
    defaultExpectedMaxSeconds: finitePositive(raw.defaultExpectedMaxSeconds, DEFAULT_POLICY.defaultExpectedMaxSeconds),
    minimumDurationSamples: finitePositive(raw.minimumDurationSamples, DEFAULT_POLICY.minimumDurationSamples),
    notificationDeliveryMode: mode,
    environment: String(raw.environment || DEFAULT_POLICY.environment).slice(0, 40),
    controlBaseUrl: String(raw.controlBaseUrl || DEFAULT_POLICY.controlBaseUrl).replace(/\/$/, ""),
    stageExpectedDurations: raw.stageExpectedDurations && typeof raw.stageExpectedDurations === "object"
      ? raw.stageExpectedDurations
      : {},
  };
}

function millis(value) {
  if (!value) return NaN;
  if (typeof value === "string") return Date.parse(value);
  if (value.toMillis) return value.toMillis();
  return Number(value);
}

function ageSeconds(value, nowMs) {
  const at = millis(value);
  if (!Number.isFinite(at)) return Infinity;
  return Math.max(0, (nowMs - at) / 1000);
}

function durationSeconds(startValue, endValue, nowMs) {
  const start = millis(startValue);
  const end = millis(endValue);
  if (!Number.isFinite(start)) return NaN;
  return Math.max(0, ((Number.isFinite(end) ? end : nowMs) - start) / 1000);
}

function stageExpectedRange(policy, stageId) {
  const raw = policy.stageExpectedDurations[String(stageId || "")] || {};
  const sampleCount = Number(raw.sampleCount) || 0;
  if (sampleCount < policy.minimumDurationSamples) return null;
  const minSeconds = finitePositive(raw.minSeconds, 0);
  const maxSeconds = finitePositive(raw.maxSeconds, 0);
  if (!minSeconds || maxSeconds < minSeconds) return null;
  return { minSeconds, maxSeconds, sampleCount };
}

function evaluateStageHealth({ job, stage, agent, policy: rawPolicy, nowMs = Date.now() }) {
  const policy = normalizePolicy(rawPolicy);
  const status = String(stage.status || job.status || "");
  if (status === WORK_STATUS.PAUSED_QUOTA || agent.state === "paused_quota") {
    return { state: "paused_quota", reason: "ai_quota_exhausted", shouldNotify: false };
  }
  if (status === WORK_STATUS.PAUSED_NETWORK || agent.state === "paused_network") {
    return { state: "paused_network", reason: "network_unavailable", shouldNotify: false };
  }
  if (status === WORK_STATUS.STALLED || agent.state === "stalled") {
    return { state: "stalled", reason: "activity_timeout", shouldNotify: true };
  }
  if ([WORK_STATUS.AI_PROCESS_FAILED, WORK_STATUS.RESULT_VALIDATION_FAILED,
    WORK_STATUS.STAGE_TRANSITION_FAILED].includes(status)) {
    return { state: "error", reason: status, shouldNotify: true };
  }
  if (status === WORK_STATUS.FAILED || agent.state === "error" || stage.errorMessage) {
    return { state: "error", shouldNotify: true };
  }
  const heartbeatAgeSeconds = ageSeconds(agent.lastHeartbeatAt, nowMs);
  if (status === WORK_STATUS.WAITING_APPROVAL || status === "awaiting_approval") {
    return {
      state: "awaiting_user",
      shouldNotify: false,
      heartbeatAgeSeconds,
      elapsedSeconds: durationSeconds(stage.startedAt || job.startedAt, stage.completedAt, nowMs),
      approvalWaitSeconds: ageSeconds(stage.completedAt || stage.lastActivityAt, nowMs),
    };
  }
  if (heartbeatAgeSeconds > policy.offlineAfterSeconds) {
    return { state: "offline", shouldNotify: true, heartbeatAgeSeconds };
  }
  const activityAgeSeconds = ageSeconds(stage.lastActivityAt || job.lastActivityAt, nowMs);
  if (activityAgeSeconds > policy.noActivityAfterSeconds) {
    return { state: "inactive", shouldNotify: true, activityAgeSeconds };
  }
  const elapsedSeconds = ageSeconds(stage.startedAt || job.startedAt, nowMs);
  const range = stageExpectedRange(policy, stage.stageId);
  const expectedMaxSeconds = range ? range.maxSeconds : policy.defaultExpectedMaxSeconds;
  if (elapsedSeconds > expectedMaxSeconds) {
    return { state: "delayed", shouldNotify: false, elapsedSeconds, expectedRange: range };
  }
  return { state: "healthy", shouldNotify: false, elapsedSeconds, expectedRange: range };
}

function notificationKey({ instructionId, stageId, revision, eventType }) {
  return [instructionId || "", stageId || "", Number(revision) || 1, eventType].join("|");
}

function deepLink({ instructionId, stageId }) {
  const query = new URLSearchParams({
    screen: "ai-production",
    projectId: String(instructionId || ""),
    stageId: String(stageId || ""),
  });
  return `/?${query.toString()}`;
}

function notificationContent(eventType, stageNumber, stageName, revision) {
  const label = `${stageNumber > 0 ? `${stageNumber}단계 ` : ""}${stageName || "제작 단계"}`;
  switch (eventType) {
    case "approval_required":
      return { title: "승인이 필요합니다", body: `${label}이 완료되었습니다. 결과를 확인하고 승인 또는 보완을 선택해주세요.` };
    case "revision_completed":
      return { title: "보완 작업 완료", body: `${label} 보완 작업 r${Math.max(2, revision || 2)}가 완료되었습니다.` };
    case "activity_stalled":
      return { title: "작업 진행 확인 필요", body: `${label} 작업이 일정 시간 동안 진행되지 않고 있습니다. 확인이 필요합니다.` };
    case "agent_offline":
      return { title: "Agent 연결 확인 필요", body: `${label} 작업 중 Agent가 오프라인 상태입니다.` };
    case "work_error":
      return { title: "AI 제작 오류", body: `${label} 작업에서 오류가 발생했습니다. 확인이 필요합니다.` };
    case "production_completed":
      return { title: "전자책 제작 완료", body: "등록 전 최종 완성본이 준비되었습니다. PDF와 등록 자료를 확인해 주세요." };
    default:
      return { title: "AI 제작공정 알림", body: `${label} 상태를 확인해주세요.` };
  }
}

async function loadPolicy(db) {
  const snap = await db.collection(COL.MONITORING_CONFIG).doc("default").get();
  return normalizePolicy(snap.exists ? snap.data() : {});
}

async function enqueueNotification(db, data, rawPolicy) {
  const policy = normalizePolicy(rawPolicy);
  const key = notificationKey(data);
  const ref = db.collection(COL.NOTIFICATION_EVENTS).doc(sha256Hex(key));
  const content = notificationContent(data.eventType, data.stageNumber, data.stageName, data.revision);
  let created = false;
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return;
    created = true;
    await tx.set(ref, {
      idempotencyKey: key,
      ownerUid: String(data.ownerUid || ""),
      instructionId: String(data.instructionId || ""),
      jobId: String(data.jobId || ""),
      stageId: String(data.stageId || ""),
      stageNumber: Number(data.stageNumber) || 0,
      stageName: String(data.stageName || "").slice(0, 120),
      revision: Number(data.revision) || 1,
      eventType: data.eventType,
      title: content.title,
      body: content.body,
      deepLink: deepLink(data),
      environment: policy.environment,
      deliveryMode: policy.notificationDeliveryMode,
      status: "pending",
      createdAt: new Date(data.nowMs || Date.now()).toISOString(),
    });
  });
  return { created, id: ref.id, idempotencyKey: key };
}

async function evaluateActiveJobs(db, nowMs = Date.now()) {
  const policy = await loadPolicy(db);
  const jobsSnap = await db.collection(COL.JOBS).get();
  const active = new Set([
    WORK_STATUS.CLAIMED,
    WORK_STATUS.RUNNING,
    WORK_STATUS.REWORKING,
    WORK_STATUS.STALLED,
    WORK_STATUS.AI_PROCESS_FAILED,
    WORK_STATUS.RESULT_VALIDATION_FAILED,
    WORK_STATUS.STAGE_TRANSITION_FAILED,
  ]);
  const results = [];
  for (const doc of jobsSnap.docs) {
    const job = doc.data() || {};
    if (!active.has(job.status) || !job.assignedAgentId || !job.currentStage) continue;
    const [agentSnap, stageSnap] = await Promise.all([
      db.collection(COL.AGENTS).doc(job.assignedAgentId).get(),
      doc.ref.collection("stages").doc(job.currentStage).get(),
    ]);
    if (!stageSnap.exists) continue;
    const stage = stageSnap.data() || {};
    const agent = agentSnap.exists ? agentSnap.data() || {} : {};
    const health = evaluateStageHealth({ job, stage, agent, policy, nowMs });
    let eventType = "";
    if (health.state === "offline") eventType = "agent_offline";
    if (health.state === "inactive") eventType = "activity_stalled";
    if (health.state === "stalled") eventType = "activity_stalled";
    if (health.state === "error") eventType = "work_error";
    if (!eventType) continue;
    if (health.state === "inactive" || health.state === "stalled") {
      const pendingRecoveryId = String(stage.recoveryCommandId || "");
      if (stage.recoveryState === "requested" && pendingRecoveryId) {
        const pending = await doc.ref.collection("commands").doc(pendingRecoveryId).get();
        const commandStatus = pending.exists ? String((pending.data() || {}).status || "") : "";
        if (commandStatus === COMMAND_STATUS.QUEUED ||
            commandStatus === COMMAND_STATUS.CLAIMED) {
          continue;
        }
      }
      const maxRecoveryAttempts = Math.max(1, Number(stage.maxRecoveryAttempts) || 3);
      const recoveryAttempt = Math.min(
        maxRecoveryAttempts,
        Math.max(0, Number(stage.recoveryAttempt) || 0) + 1
      );
      const exhausted = recoveryAttempt >= maxRecoveryAttempts;
      const status = exhausted
        ? WORK_STATUS.STAGE_TRANSITION_FAILED
        : WORK_STATUS.STALLED;
      const ts = new Date(nowMs).toISOString();
      const recoveryPatch = {
        status,
        activityState: status,
        recoveryAttempt,
        maxRecoveryAttempts,
        recoveryState: exhausted ? "exhausted" : "requested",
        retryable: !exhausted,
        failureType: exhausted ? "stalled_recovery_exhausted" : "activity_timeout",
        failureReason: exhausted
          ? `automatic recovery exhausted (${recoveryAttempt}/${maxRecoveryAttempts})`
          : `automatic recovery requested (${recoveryAttempt}/${maxRecoveryAttempts})`,
        updatedAt: ts,
      };
      if (!exhausted) {
        const commands = await doc.ref.collection("commands").get();
        const original = commands.docs
          .map((item) => item.data() || {})
          .find((item) => item.type === COMMAND_TYPE.START_JOB && item.payload);
        if (original) {
          const recoveryCommandId = `cmd_recovery_${sha256Hex(
            `${doc.id}:${job.currentStage}:${recoveryAttempt}`
          ).slice(0, 24)}`;
          await doc.ref.collection("commands").doc(recoveryCommandId).set({
            commandId: recoveryCommandId,
            idempotencyKey: `recovery:${doc.id}:${job.currentStage}:${recoveryAttempt}`,
            agentId: job.assignedAgentId,
            jobId: job.jobId || doc.id,
            type: COMMAND_TYPE.START_JOB,
            status: COMMAND_STATUS.QUEUED,
            attempt: 0,
            payload: {
              ...original.payload,
              recovery: {
                stageId: job.currentStage,
                attempt: recoveryAttempt,
                maxAttempts: maxRecoveryAttempts,
              },
            },
            createdAt: ts,
            updatedAt: ts,
          }, { merge: true });
          recoveryPatch.recoveryCommandId = recoveryCommandId;
        } else {
          recoveryPatch.recoveryState = "unavailable";
          recoveryPatch.retryable = false;
          recoveryPatch.failureReason = "automatic recovery unavailable: START_JOB payload missing";
        }
      }
      await doc.ref.collection("stages").doc(job.currentStage)
        .set(recoveryPatch, { merge: true });
      await doc.ref.set({
        ...recoveryPatch,
        pauseReason: status,
      }, { merge: true });
      if (job.instructionId) {
        const projectRef = db.collection(COL.PROJECTS).doc(job.instructionId);
        await projectRef.collection("stages").doc(job.currentStage)
          .set(recoveryPatch, { merge: true });
        await projectRef.set(recoveryPatch, { merge: true });
      }
    }
    const out = await enqueueNotification(db, {
      ownerUid: job.ownerUid,
      instructionId: job.instructionId,
      jobId: job.jobId || doc.id,
      stageId: stage.stageId || job.currentStage,
      stageNumber: stage.stageNumber,
      stageName: stage.stageName,
      revision: stage.revision,
      eventType,
      nowMs,
    }, policy);
    results.push({ jobId: doc.id, health: health.state, ...out });
  }
  return results;
}

async function deliverNotificationEvent(db, messaging, eventId) {
  const ref = db.collection(COL.NOTIFICATION_EVENTS).doc(eventId);
  const snap = await ref.get();
  if (!snap.exists) return { delivered: 0, skipped: "missing" };
  const event = snap.data() || {};
  if (event.status !== "pending") return { delivered: 0, skipped: "already_processed" };
  const policy = await loadPolicy(db);
  if (event.deliveryMode !== "fcm" || policy.notificationDeliveryMode !== "fcm") {
    await ref.set({ status: "outbox_only", processedAt: new Date().toISOString() }, { merge: true });
    return { delivered: 0, skipped: "outbox_only" };
  }
  if (!event.ownerUid) {
    await ref.set({ status: "failed", failureCode: "owner_missing", processedAt: new Date().toISOString() }, { merge: true });
    return { delivered: 0, skipped: "owner_missing" };
  }
  const tokenSnap = await db.collection(COL.USERS).doc(event.ownerUid)
    .collection("notificationTokens").get();
  const tokens = tokenSnap.docs
    .map((d) => String((d.data() || {}).token || ""))
    .filter(Boolean)
    .slice(0, 500);
  if (tokens.length === 0) {
    await ref.set({ status: "no_targets", processedAt: new Date().toISOString() }, { merge: true });
    return { delivered: 0, skipped: "no_targets" };
  }
  const link = `${policy.controlBaseUrl}${event.deepLink || "/?screen=ai-production"}`;
  const result = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: event.title || "AI 제작공정", body: event.body || "상태를 확인해주세요." },
    data: {
      deepLink: String(event.deepLink || ""),
      instructionId: String(event.instructionId || ""),
      stageId: String(event.stageId || ""),
      eventType: String(event.eventType || ""),
    },
    webpush: { fcmOptions: { link } },
  });
  await ref.set({
    status: result.failureCount === result.responses.length ? "failed" : "delivered",
    deliveredCount: result.successCount,
    failedCount: result.failureCount,
    processedAt: new Date().toISOString(),
  }, { merge: true });
  return { delivered: result.successCount, failed: result.failureCount };
}

module.exports = {
  DEFAULT_POLICY,
  normalizePolicy,
  evaluateStageHealth,
  notificationKey,
  notificationContent,
  deepLink,
  loadPolicy,
  enqueueNotification,
  evaluateActiveJobs,
  deliverNotificationEvent,
};
