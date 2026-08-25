"use strict";

const {
  EBOOK_STAGE_CONTRACTS,
  EBOOK_STAGE_BY_ID,
  APP_STAGE_BY_ID,
  stageContractsForProduct,
  stageMapForProduct,
} = require("./canonical");

const STATUS_RANK = Object.freeze({
  ready: 0,
  in_progress: 1,
  running: 1,
  revision: 1,
  reworking: 1,
  paused_quota: 1,
  paused_network: 1,
  stalled: 1,
  ai_process_failed: 1,
  result_validation_failed: 1,
  result_validation_retrying: 1,
  stage_transition_failed: 1,
  awaiting_approval: 2,
  waiting_approval: 2,
  completed: 3,
  not_applicable: 3,
  prelaunch_review: 4,
  awaiting_launch_approval: 5,
  launch_approved: 6,
  launching: 7,
  launched: 8,
});

const PRODUCTION_RANK = Object.freeze({
  ai_production: 0, approval_pending: 1, revision_in_progress: 2,
  production_complete: 3, prelaunch_review: 4,
});
const LAUNCH_RANK = Object.freeze({
  not_started: 0, awaiting_launch_approval: 1, launch_approved: 2,
  manual_registration_required: 3, launching: 4, launched: 5,
});

function preserveProductionLaunch(previous, incoming) {
  const prior = previous || {};
  const next = { ...incoming };
  const priorRevision = Math.max(1, Number(prior.finalRevision) || 1);
  const nextRevision = Math.max(1, Number(next.finalRevision) || 1);
  const productionRegressed = (PRODUCTION_RANK[prior.productionStatus] ?? 0) >
    (PRODUCTION_RANK[next.productionStatus] ?? 0);
  // A newer revision may deliberately re-enter revision_in_progress.
  if (productionRegressed && nextRevision <= priorRevision) {
    next.productionStatus = prior.productionStatus;
    next.productionCompletedAt = prior.productionCompletedAt;
    next.finalRevision = prior.finalRevision;
  }
  if ((LAUNCH_RANK[prior.launchStatus] ?? 0) > (LAUNCH_RANK[next.launchStatus] ?? 0)) {
    next.launchStatus = prior.launchStatus;
    next.externalPublished = prior.externalPublished === true;
    if (["awaiting_launch_approval", "launch_approved", "launching", "launched"].includes(prior.status)) {
      next.status = prior.status;
    }
  }
  if (prior.externalPublished === true) next.externalPublished = true;
  return next;
}

const TERMINAL_DECISIONS = new Set(["approved", "revision_requested"]);
const AUTHORITATIVE_STAGE_FIELDS = Object.freeze([
  "status",
  "criteriaMet",
  "approvalRequired",
  "approvalStatus",
  "activeRequestId",
  "revision",
  "resultVersion",
  "completedAt",
  "resultUrl",
  "previewUrl",
  "artifactUrl",
  "artifactPreviewUrl",
  "attemptCount",
  "maxAttempts",
  "retryCount",
  "maxRetries",
  "nextRetryAt",
  "retryable",
  "failureType",
  "failureReason",
  "recoveryAttempt",
  "maxRecoveryAttempts",
  "recoveryState",
  "recoveryCommandId",
]);

function normalizedRevision(value) {
  return Math.max(1, Number(value && value.revision) || 1);
}

function statusRank(status) {
  return STATUS_RANK[String(status || "")] ?? 0;
}

function mergeMonotonicStage(previous, incoming) {
  const prior = previous || {};
  const next = { ...incoming };
  const previousRevision = normalizedRevision(prior);
  const incomingRevision = normalizedRevision(next);
  const staleRevision = incomingRevision < previousRevision;
  const sameRevisionRegression = incomingRevision === previousRevision &&
    statusRank(prior.status) > statusRank(next.status);
  const staleRetryAttempt = incomingRevision === previousRevision &&
    statusRank(next.status) <= 1 && Number(prior.attemptCount || 0) > 0 &&
    Number(next.attemptCount || 0) < Number(prior.attemptCount || 0);
  const staleStallRecovery = incomingRevision === previousRevision &&
    ["stalled", "stage_transition_failed"].includes(String(prior.status || "")) &&
    ["ready", "in_progress", "running"].includes(String(next.status || "")) &&
    Number(next.attemptCount || 0) <= Number(prior.attemptCount || 0);
  if (!staleRevision && !sameRevisionRegression && !staleRetryAttempt &&
      !staleStallRecovery) return next;

  for (const field of AUTHORITATIVE_STAGE_FIELDS) {
    if (prior[field] !== undefined) next[field] = prior[field];
    else delete next[field];
  }
  return next;
}

function preserveTerminalDecision(previous, incoming, payload) {
  const sameRevision = normalizedRevision(incoming) === normalizedRevision(previous);
  if (sameRevision && TERMINAL_DECISIONS.has(String(previous.approvalStatus || "")) &&
      !TERMINAL_DECISIONS.has(String(incoming.approvalStatus || ""))) {
    payload.approvalStatus = previous.approvalStatus;
    if (previous.activeRequestId) payload.activeRequestId = previous.activeRequestId;
  }
  return payload;
}

function currentOrder(value) {
  const direct = Number(value && (value.currentStageNumber || value.currentStage));
  if (Number.isInteger(direct) && direct > 0) return direct;
  const id = String(value && (value.currentStageId || value.currentStage) || "");
  return EBOOK_STAGE_BY_ID.get(id)?.order || APP_STAGE_BY_ID.get(id)?.order || 0;
}

function mergeMonotonicProject(previous, incoming) {
  const prior = previous || {};
  const next = { ...incoming };
  const priorOrder = currentOrder(prior);
  const nextOrder = currentOrder(next);
  const regressedStage = priorOrder > 0 && nextOrder > 0 && nextOrder < priorOrder;
  const sameStageRegression = priorOrder > 0 && priorOrder === nextOrder &&
    statusRank(prior.status) > statusRank(next.status);
  const staleRetryAttempt = priorOrder > 0 && priorOrder === nextOrder &&
    statusRank(next.status) <= 1 && Number(prior.attemptCount || 0) > 0 &&
    Number(next.attemptCount || 0) < Number(prior.attemptCount || 0);
  const staleStallRecovery = priorOrder > 0 && priorOrder === nextOrder &&
    ["stalled", "stage_transition_failed"].includes(String(prior.status || "")) &&
    ["ready", "in_progress", "running"].includes(String(next.status || "")) &&
    Number(next.attemptCount || 0) <= Number(prior.attemptCount || 0);
  if (!regressedStage && !sameStageRegression && !staleRetryAttempt &&
      !staleStallRecovery) return preserveProductionLaunch(prior, next);

  for (const field of [
    "currentStage",
    "currentStageId",
    "currentStageNumber",
    "status",
    "approvalStatus",
    "approvalRequired",
    "currentStageCriteriaMet",
    "completedAt",
    "attemptCount",
    "maxAttempts",
    "retryCount",
    "maxRetries",
    "nextRetryAt",
    "retryable",
    "failureType",
    "failureReason",
    "recoveryAttempt",
    "maxRecoveryAttempts",
    "recoveryState",
    "recoveryCommandId",
  ]) {
    if (prior[field] !== undefined) next[field] = prior[field];
    else delete next[field];
  }
  return preserveProductionLaunch(prior, next);
}

function alignProjectWithCurrentStage(project, stages) {
  const out = { ...project };
  const order = currentOrder(project);
  const current = stages.find((stage) => Number(stage.stageNumber) === order) ||
    stages.find((stage) => stage.stageId === project.currentStageId);
  if (!current) return out;
  if (current.status === "awaiting_approval" || current.status === "waiting_approval") {
    out.status = "awaiting_approval";
    out.approvalStatus = "pending";
    out.approvalRequired = true;
    out.currentStageCriteriaMet = current.criteriaMet === true;
  }
  const canonicalStage = EBOOK_STAGE_BY_ID.get(current.stageId) || APP_STAGE_BY_ID.get(current.stageId);
  if (current.status === "completed" && canonicalStage?.terminal) {
    if (current.stageId === "app_production_complete") {
      const desiredRevision = Math.max(1, Number(project.finalRevision) || 1);
      const apkStage = stages
        .filter((stage) => stage.stageId === "app_android_release" || (
          stage.stageId === "app_production_complete" &&
          Math.max(1, Number(stage.revision) || 1) >= 2
        ))
        .filter((stage) => Math.max(1, Number(stage.revision) || 1) === desiredRevision)
        .pop();
      let apkUrlValid = false;
      try {
        const value = String(apkStage && (apkStage.resultUrl || apkStage.previewUrl) || "");
        const url = new URL(value);
        apkUrlValid = url.protocol === "https:" && /\/app-release_r\d+\.apk$/i.test(url.pathname);
      } catch (_) {}
      if (!apkStage || apkStage.status !== "completed" || apkStage.criteriaMet !== true || !apkUrlValid) {
        out.status = "stage_transition_failed";
        out.productionStatus = "ai_production";
        out.launchStatus = out.launchStatus || "not_started";
        out.externalPublished = false;
        return out;
      }
    }
    out.status = "prelaunch_review";
    out.productionStatus = "prelaunch_review";
    out.launchStatus = out.launchStatus || "not_started";
    out.externalPublished = out.externalPublished === true;
    out.approvalStatus = current.approvalStatus || "not_required";
    out.progress = 100;
  }
  return out;
}

function createSimulation({ approvalRequiredOverride, productType = "ebook" } = {}) {
  const contracts = stageContractsForProduct(productType);
  const stages = contracts.map((contract) => ({
    stageId: contract.id,
    stageNumber: contract.order,
    status: contract.applicableByDefault ? "ready" : "not_applicable",
    criteriaMet: false,
    approvalRequired: false,
    approvalStatus: "not_required",
    revision: 1,
  }));
  const first = stages.find((stage) => stage.status === "ready");
  first.status = "in_progress";
  return {
    currentStageId: first.stageId,
    status: "in_progress",
    stages,
    requests: new Map(),
    workflowReceipts: new Set(),
    approvalRequiredOverride,
    productType,
  };
}

function currentStage(state) {
  return state.stages.find((stage) => stage.stageId === state.currentStageId);
}

function stageNeedsApproval(state, stage) {
  if (typeof state.approvalRequiredOverride === "boolean") {
    return state.approvalRequiredOverride;
  }
  return stageMapForProduct(state.productType || "ebook")
    .get(stage.stageId)?.approvalTypicallyRequired === true;
}

function advance(state) {
  const current = currentStage(state);
  const next = state.stages.find((stage) =>
    stage.stageNumber > current.stageNumber && stage.status !== "not_applicable");
  if (!next) {
    state.status = "completed";
    return;
  }
  next.status = "in_progress";
  state.currentStageId = next.stageId;
  state.status = "in_progress";
}

function reportValidatedResult(state) {
  const stage = currentStage(state);
  if (!stage || stage.status !== "in_progress") throw new Error("stage_not_running");
  stage.criteriaMet = true;
  stage.approvalRequired = stageNeedsApproval(state, stage);
  if (stage.approvalRequired) {
    stage.status = "awaiting_approval";
    stage.approvalStatus = "pending";
    state.status = "awaiting_approval";
  } else {
    stage.status = "completed";
    stage.approvalStatus = "not_required";
    advance(state);
  }
}

function submitDecision(state, decision) {
  const stage = currentStage(state);
  if (!stage || stage.status !== "awaiting_approval" || !stage.criteriaMet) {
    throw new Error("stage_not_approvable");
  }
  const key = `${stage.stageId}|${stage.revision}`;
  const existing = state.requests.get(key);
  if (existing) return { ...existing, idempotent: true };
  const request = {
    requestId: `req_${stage.stageId}_r${stage.revision}`,
    stageId: stage.stageId,
    revision: stage.revision,
    decision,
    processed: true,
    workflowApplied: false,
  };
  state.requests.set(key, request);
  stage.activeRequestId = request.requestId;
  stage.approvalStatus = decision;
  if (decision === "revision_requested") {
    stage.revision += 1;
    stage.status = "in_progress";
    stage.criteriaMet = false;
    stage.approvalRequired = false;
    stage.approvalStatus = "not_required";
    state.status = "in_progress";
    return request;
  }
  if (decision !== "approved") throw new Error("decision_invalid");
  stage.status = "completed";
  request.workflowApplied = true;
  state.workflowReceipts.add(request.requestId);
  advance(state);
  return request;
}

module.exports = {
  STATUS_RANK,
  normalizedRevision,
  statusRank,
  mergeMonotonicStage,
  preserveTerminalDecision,
  mergeMonotonicProject,
  preserveProductionLaunch,
  alignProjectWithCurrentStage,
  createSimulation,
  currentStage,
  reportValidatedResult,
  submitDecision,
};
