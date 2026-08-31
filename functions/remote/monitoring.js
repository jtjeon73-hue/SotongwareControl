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

function notificationKey(data) {
  return [
    data.ownerUid || "",
    data.instructionId || "",
    data.jobId || "",
    data.stageId || "",
    Number(data.revision) || 1,
    data.eventType || "",
    data.artifactId || "",
    data.resourceProvider || "",
    Number(data.thresholdPercent) || 0,
    data.resourceWindowId || "",
    data.idempotencyDiscriminator || "",
  ].join("|");
}

function deepLink(data) {
  if (String(data.eventType || "").startsWith("ai_usage_") ||
      data.eventType === "ai_quota_exhausted") {
    return "/?screen=remote-control";
  }
  if (data.eventType === "test_notification") {
    return "/?screen=system-settings";
  }
  if (data.eventType === "apk_ready_for_device_review") {
    const query = new URLSearchParams({
      screen: "ai-production",
      projectId: String(data.instructionId || ""),
      stageId: String(data.stageId || "app_android_release"),
      focus: "apk",
    });
    return `/?${query.toString()}`;
  }
  const { instructionId, stageId } = data;
  const query = new URLSearchParams({
    screen: "ai-production",
    projectId: String(instructionId || ""),
    stageId: String(stageId || ""),
  });
  return `/?${query.toString()}`;
}

function notificationContent(eventType, stageNumber, stageName, revision, data = {}) {
  const label = `${stageNumber > 0 ? `${stageNumber}단계 ` : ""}${stageName || "제작 단계"}`;
  switch (eventType) {
    case "approval_required":
      return { title: "승인이 필요합니다", body: `${label}이 완료되었습니다. 결과를 확인하고 승인 또는 보완을 선택해주세요.` };
    case "revision_completed":
      return { title: "보완 작업 완료", body: `${label} 보완 작업 r${Math.max(2, revision || 2)}가 완료되었습니다. 재검토해 주세요.` };
    case "activity_stalled":
      return { title: "작업 진행 확인 필요", body: `${label} 작업이 일정 시간 동안 진행되지 않고 있습니다. 확인이 필요합니다.` };
    case "agent_offline":
      return { title: "Agent 연결 확인 필요", body: `${label} 작업 중 Agent가 오프라인 상태입니다.` };
    case "work_error":
      return { title: "AI 제작 오류", body: `${label} 작업에서 오류가 발생했습니다. 확인이 필요합니다.` };
    case "recovery_exhausted":
      return { title: "자동복구 실패", body: `${label} 자동복구가 모두 실패했습니다. 사용자 확인이 필요합니다.` };
    case "ai_usage_warning":
      return { title: `${data.resourceProvider || "AI 작업자"} 사용량 주의`, body: `확인된 사용량이 ${Number(data.usagePercent) || 0}%입니다. 남은 작업량을 확인해 주세요.` };
    case "ai_usage_high":
      return { title: `${data.resourceProvider || "AI 작업자"} 사용량 경고`, body: `확인된 사용량이 ${Number(data.usagePercent) || 0}%입니다. 작업자 전환을 준비해 주세요.` };
    case "ai_usage_critical":
      return { title: `${data.resourceProvider || "AI 작업자"} 사용량 긴급`, body: `확인된 사용량이 ${Number(data.usagePercent) || 0}%입니다. 작업 중단 가능성을 확인해 주세요.` };
    case "ai_quota_exhausted":
      return { title: `${data.resourceProvider || "AI 작업자"} 사용 한도 소진`, body: "AI 작업자 한도가 소진되어 작업자 전환 또는 사용자 조치가 필요합니다." };
    case "apk_ready_for_device_review": {
      const appLabel = String(data.appName || "앱").trim() || "앱";
      return {
        title: "앱 설치본 준비 완료",
        body: `${appLabel} APK가 준비되었습니다. 소통총관제에서 다운로드하여 휴대폰 설치 테스트를 진행해주세요.`,
      };
    }
    case "production_completed":
      if (data.productType === "app") {
        return { title: "앱 제작 완료", body: "앱 제작이 완료되었습니다. APK를 설치하여 확인해 주세요." };
      }
      return { title: "전자책 제작 완료", body: "전자책 제작이 완료되었습니다. 결과를 확인해 주세요." };
    case "test_notification":
      return { title: "소통총관제 테스트 알림", body: "이 기기에서 운영 알림을 정상적으로 받을 수 있습니다." };
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
  const content = notificationContent(
    data.eventType,
    data.stageNumber,
    data.stageName,
    data.revision,
    data
  );
  let created = false;
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return;
    created = true;
    await tx.set(ref, {
      idempotencyKey: key,
      notificationEventId: ref.id,
      ownerUid: String(data.ownerUid || ""),
      instructionId: String(data.instructionId || ""),
      jobId: String(data.jobId || ""),
      stageId: String(data.stageId || ""),
      stageNumber: Number(data.stageNumber) || 0,
      stageName: String(data.stageName || "").slice(0, 120),
      revision: Number(data.revision) || 1,
      eventType: data.eventType,
      severity: String(data.severity || "info").slice(0, 20),
      actionRequired: data.actionRequired === true,
      source: String(data.source || "workflow").slice(0, 40),
      productType: String(data.productType || "ebook").slice(0, 30),
      appName: String(data.appName || "").slice(0, 120),
      artifactId: String(data.artifactId || "").slice(0, 64),
      storagePath: String(data.storagePath || "").slice(0, 240),
      sizeBytes: Number.isFinite(Number(data.sizeBytes)) ? Number(data.sizeBytes) : null,
      resourceProvider: String(data.resourceProvider || "").slice(0, 40),
      resourceWindowId: String(data.resourceWindowId || "").slice(0, 80),
      thresholdPercent: Number(data.thresholdPercent) || 0,
      usagePercent: Number.isFinite(Number(data.usagePercent))
        ? Number(data.usagePercent)
        : null,
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
    WORK_STATUS.PAUSED_QUOTA,
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
    if (health.state === "paused_quota") eventType = "ai_quota_exhausted";
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
          const originalAiExecution = original.payload.aiExecution || {};
          const originalWorker = String(originalAiExecution.worker || "").toLowerCase();
          const artifactType = String(original.payload.artifactType || "").toLowerCase();
          const codexWeeklyUsed = Number(
            agent.aiUsage && agent.aiUsage.codex &&
            agent.aiUsage.codex.weekly && agent.aiUsage.codex.weekly.usedPercent
          );
          const codexAvailable = Number.isFinite(codexWeeklyUsed) && codexWeeklyUsed < 100;
          const selectedWorker = artifactType === "app" &&
            originalWorker === "cursor" && codexAvailable
            ? "codex"
            : originalWorker;
          const recoveryAction = recoveryAttempt === 1
            ? "stale_worker_recheck_and_executor_redispatch"
            : "ownership_reconcile_and_executor_redispatch";
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
              aiExecution: {
                ...originalAiExecution,
                worker: selectedWorker,
              },
              recovery: {
                stageId: job.currentStage,
                attempt: recoveryAttempt,
                maxAttempts: maxRecoveryAttempts,
                action: recoveryAction,
                previousWorker: originalWorker,
                selectedWorker,
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
          eventType = "recovery_exhausted";
        }
      }
      if (exhausted) eventType = "recovery_exhausted";
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
      severity: eventType === "recovery_exhausted" || eventType === "work_error"
        ? "critical"
        : "warning",
      actionRequired: eventType === "recovery_exhausted" ||
        eventType === "work_error" || eventType === "ai_quota_exhausted",
      nowMs,
    }, policy);
    results.push({ jobId: doc.id, health: health.state, ...out });
  }
  return results;
}

function usageThreshold(usedPercent) {
  const value = Number(usedPercent);
  if (!Number.isFinite(value) || value < 0 || value > 100) return null;
  if (value >= 100) return { eventType: "ai_quota_exhausted", thresholdPercent: 100, severity: "critical" };
  if (value >= 95) return { eventType: "ai_usage_critical", thresholdPercent: 95, severity: "critical" };
  if (value >= 85) return { eventType: "ai_usage_high", thresholdPercent: 85, severity: "warning" };
  if (value >= 70) return { eventType: "ai_usage_warning", thresholdPercent: 70, severity: "warning" };
  return null;
}

async function evaluateAiUsageNotifications(db, nowMs = Date.now()) {
  const policy = await loadPolicy(db);
  const agents = await db.collection(COL.AGENTS).get();
  const results = [];
  for (const doc of agents.docs) {
    const agent = doc.data() || {};
    if (!agent.ownerUid || agent.enabled === false) continue;
    const candidates = [];
    const codex = agent.aiUsage && agent.aiUsage.codex;
    if (codex && codex.weekly && Number.isFinite(Number(codex.weekly.usedPercent))) {
      candidates.push({
        provider: "Codex",
        usedPercent: Number(codex.weekly.usedPercent),
        windowId: String(codex.weekly.resetsAtIso || codex.weekly.resetsAt || "unknown-window"),
      });
    }
    const cursor = agent.aiUsage && agent.aiUsage.cursor;
    if (cursor && cursor.source === "manual" && Number.isFinite(Number(cursor.usedPercent))) {
      candidates.push({
        provider: "Cursor",
        usedPercent: Number(cursor.usedPercent),
        windowId: String(cursor.resetsAt || "unknown-window"),
      });
    }
    for (const candidate of candidates) {
      const threshold = usageThreshold(candidate.usedPercent);
      if (!threshold) continue;
      const out = await enqueueNotification(db, {
        ownerUid: agent.ownerUid,
        jobId: String(agent.currentJobId || ""),
        stageId: String(agent.currentStage || ""),
        revision: 1,
        eventType: threshold.eventType,
        severity: threshold.severity,
        actionRequired: threshold.thresholdPercent >= 95,
        source: "ai_worker_telemetry",
        resourceProvider: candidate.provider,
        resourceWindowId: candidate.windowId,
        thresholdPercent: threshold.thresholdPercent,
        usagePercent: candidate.usedPercent,
        idempotencyDiscriminator: doc.id,
        nowMs,
      }, policy);
      results.push({ agentId: doc.id, provider: candidate.provider, ...out });
    }
  }
  return results;
}

async function deliverNotificationEvent(db, messaging, eventId) {
  const ref = db.collection(COL.NOTIFICATION_EVENTS).doc(eventId);
  let event = null;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const current = snap.data() || {};
    if (current.status !== "pending") return;
    event = current;
    tx.set(ref, {
      status: "sending",
      deliveryStartedAt: new Date().toISOString(),
    }, { merge: true });
  });
  if (!event) {
    const snap = await ref.get();
    return { delivered: 0, skipped: snap.exists ? "already_processed" : "missing" };
  }
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
  const targets = tokenSnap.docs
    .map((d) => ({ ref: d.ref, id: d.id, data: d.data() || {} }))
    .filter((item) => item.data.enabled !== false && String(item.data.token || ""))
    .slice(0, 500);
  if (targets.length === 0) {
    await ref.set({ status: "no_targets", processedAt: new Date().toISOString() }, { merge: true });
    return { delivered: 0, skipped: "no_targets" };
  }
  const link = `${policy.controlBaseUrl}${event.deepLink || "/?screen=ai-production"}`;
  let result;
  try {
    result = await messaging.sendEachForMulticast({
      tokens: targets.map((item) => String(item.data.token)),
      notification: { title: event.title || "AI 제작공정", body: event.body || "상태를 확인해주세요." },
      data: {
        deepLink: String(event.deepLink || ""),
        instructionId: String(event.instructionId || ""),
        stageId: String(event.stageId || ""),
        eventType: String(event.eventType || ""),
        notificationEventId: String(event.notificationEventId || eventId),
      },
      webpush: { fcmOptions: { link } },
    });
  } catch (err) {
    await ref.set({
      status: "failed",
      failureCode: String(err && (err.code || err.message) || "send_failed").slice(0, 160),
      processedAt: new Date().toISOString(),
    }, { merge: true });
    throw err;
  }
  const staleCodes = new Set([
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token",
  ]);
  const deliveries = {};
  for (let i = 0; i < targets.length; i += 1) {
    const response = result.responses[i] || {};
    const code = String(response.error && response.error.code || "");
    deliveries[targets[i].id] = response.success === true ? "delivered" : (code || "failed");
    if (staleCodes.has(code)) await targets[i].ref.delete();
  }
  await ref.set({
    status: result.successCount === 0
      ? "failed"
      : result.failureCount > 0 ? "partial" : "delivered",
    deliveredCount: result.successCount,
    failedCount: result.failureCount,
    recipientDeviceCount: targets.length,
    deliveries,
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
  usageThreshold,
  evaluateAiUsageNotifications,
  deliverNotificationEvent,
};
