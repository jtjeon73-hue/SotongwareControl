"use strict";

const { EBOOK_STAGE_CONTRACTS, EBOOK_STAGE_BY_ID } = require("./canonical");

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
  stage_transition_failed: 1,
  awaiting_approval: 2,
  waiting_approval: 2,
  completed: 3,
  not_applicable: 3,
});

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
  if (!staleRevision && !sameRevisionRegression) return next;

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
  return EBOOK_STAGE_BY_ID.get(id)?.order || 0;
}

function mergeMonotonicProject(previous, incoming) {
  const prior = previous || {};
  const next = { ...incoming };
  const priorOrder = currentOrder(prior);
  const nextOrder = currentOrder(next);
  const regressedStage = priorOrder > 0 && nextOrder > 0 && nextOrder < priorOrder;
  const sameStageRegression = priorOrder > 0 && priorOrder === nextOrder &&
    statusRank(prior.status) > statusRank(next.status);
  if (!regressedStage && !sameStageRegression) return next;

  for (const field of [
    "currentStage",
    "currentStageId",
    "currentStageNumber",
    "status",
    "approvalStatus",
    "approvalRequired",
    "currentStageCriteriaMet",
    "completedAt",
  ]) {
    if (prior[field] !== undefined) next[field] = prior[field];
    else delete next[field];
  }
  return next;
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
  if (current.status === "completed" && EBOOK_STAGE_BY_ID.get(current.stageId)?.terminal) {
    out.status = "completed";
    out.approvalStatus = current.approvalStatus || "not_required";
    out.progress = 100;
  }
  return out;
}

function createSimulation({ approvalRequiredOverride } = {}) {
  const stages = EBOOK_STAGE_CONTRACTS.map((contract) => ({
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
  };
}

function currentStage(state) {
  return state.stages.find((stage) => stage.stageId === state.currentStageId);
}

function stageNeedsApproval(state, stage) {
  if (typeof state.approvalRequiredOverride === "boolean") {
    return state.approvalRequiredOverride;
  }
  return EBOOK_STAGE_BY_ID.get(stage.stageId)?.approvalTypicallyRequired === true;
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
  alignProjectWithCurrentStage,
  createSimulation,
  currentStage,
  reportValidatedResult,
  submitDecision,
};
