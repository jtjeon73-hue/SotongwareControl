"use strict";

const assert = require("node:assert/strict");
const { describe, it } = require("node:test");
const {
  EBOOK_STAGE_CONTRACTS,
  PROBLEM_VALIDATE_EVIDENCE_CONTRACT,
} = require("../sotong24/canonical");
const {
  createSimulation,
  currentStage,
  reportValidatedResult,
  submitDecision,
  mergeMonotonicStage,
  mergeMonotonicProject,
} = require("../sotong24/state_machine");

describe("canonical ebook 18-stage state machine", () => {
  it("publishes the canonical STEP 2 evidence thresholds", () => {
    assert.deepEqual(PROBLEM_VALIDATE_EVIDENCE_CONTRACT, {
      minPublicSourceUrls: 5,
      minIndependentDomains: 3,
      minProblemSignals: 10,
      requiredProfiles: 2,
      directInterviewPolicy: "declare_conducted_or_not_conducted",
      noInterviewFallback: "public_voice_of_customer",
      signalIdSchemes: ["S", "PS"],
    });
    assert.strictEqual(
      EBOOK_STAGE_CONTRACTS[1].evidenceContract,
      PROBLEM_VALIDATE_EVIDENCE_CONTRACT,
    );
  });

  it("treats STEP 12 as AI production boundary, not external publish", () => {
    const publishPrep = EBOOK_STAGE_CONTRACTS.find((stage) => stage.id === "publish_prep");
    const deploy = EBOOK_STAGE_CONTRACTS.find((stage) => stage.id === "deploy");
    assert.equal(publishPrep.order, 12);
    assert.equal(publishPrep.aiDocumentStage, true);
    assert.equal(publishPrep.productionBoundary, true);
    assert.equal(deploy.aiDocumentStage, false);
    assert.equal(deploy.productionBoundary, false);
  });

  it("runs deterministic stage 1 through 18 with exactly-once approval", () => {
    const state = createSimulation({ approvalRequiredOverride: true });
    const transitions = [];
    while (state.status !== "completed") {
      const stage = currentStage(state);
      const beforeId = stage.stageId;
      assert.equal(stage.status, "in_progress");
      reportValidatedResult(state);
      assert.equal(stage.criteriaMet, true);
      assert.equal(stage.approvalRequired, true);
      assert.equal(stage.status, "awaiting_approval");
      const applied = submitDecision(state, "approved");
      assert.equal(applied.workflowApplied, true);
      assert.equal(stage.status, "completed");
      assert.equal(state.workflowReceipts.has(applied.requestId), true);
      transitions.push(beforeId);
      if (state.status !== "completed") {
        assert.equal(currentStage(state).status, "in_progress");
      }
    }

    const applicable = EBOOK_STAGE_CONTRACTS.filter((stage) => stage.applicableByDefault);
    assert.deepEqual(transitions, applicable.map((stage) => stage.id));
    assert.equal(state.stages.length, 18);
    assert.equal(state.stages.filter((stage) => stage.status === "completed").length, 16);
    assert.equal(state.stages.filter((stage) => stage.status === "not_applicable").length, 2);
    assert.equal(state.requests.size, 16);
    assert.equal(state.workflowReceipts.size, 16);
    assert.equal(state.status, "completed");
  });

  it("auto-advances every approval-free stage", () => {
    const state = createSimulation({ approvalRequiredOverride: false });
    const visited = [];
    while (state.status !== "completed") {
      visited.push(currentStage(state).stageId);
      reportValidatedResult(state);
    }
    assert.equal(state.requests.size, 0);
    assert.equal(visited.length, 16);
    assert.equal(state.status, "completed");
  });

  it("supports r1 revision to r2 and rejects reuse of the r1 slot", () => {
    const state = createSimulation({ approvalRequiredOverride: true });
    while (currentStage(state).stageId !== "planning") {
      reportValidatedResult(state);
      submitDecision(state, "approved");
    }
    reportValidatedResult(state);
    const r1 = submitDecision(state, "revision_requested");
    const stage = currentStage(state);
    assert.equal(stage.stageId, "planning");
    assert.equal(stage.revision, 2);
    assert.equal(stage.status, "in_progress");
    reportValidatedResult(state);
    const r2 = submitDecision(state, "approved");
    assert.notEqual(r1.requestId, r2.requestId);
    assert.equal(r1.revision, 1);
    assert.equal(r2.revision, 2);
    assert.equal(r2.workflowApplied, true);
    assert.equal(currentStage(state).stageId, "project_setup");
  });

  it("survives stale sync, duplicate decision, reconnect, and old revision faults", () => {
    const awaiting = {
      stageId: "materials_prep",
      stageNumber: 3,
      status: "awaiting_approval",
      criteriaMet: true,
      approvalRequired: true,
      approvalStatus: "approved",
      activeRequestId: "req_materials_prep_r1",
      revision: 1,
      resultUrl: "https://example.invalid/r1.md",
    };
    const stale = mergeMonotonicStage(awaiting, {
      stageId: "materials_prep",
      stageNumber: 3,
      status: "in_progress",
      criteriaMet: false,
      approvalRequired: false,
      approvalStatus: "pending",
      revision: 1,
    });
    assert.equal(stale.status, "awaiting_approval");
    assert.equal(stale.criteriaMet, true);
    assert.equal(stale.approvalStatus, "approved");

    const stalled = mergeMonotonicStage(
      {
        stageId: "publish_prep",
        stageNumber: 12,
        status: "stalled",
        revision: 1,
        recoveryAttempt: 1,
      },
      {
        stageId: "publish_prep",
        stageNumber: 12,
        status: "in_progress",
        revision: 1,
      },
    );
    assert.equal(stalled.status, "stalled");
    assert.equal(stalled.recoveryAttempt, 1);

    const completed = mergeMonotonicStage({ ...awaiting, status: "completed" }, awaiting);
    assert.equal(completed.status, "completed");
    const oldRevision = mergeMonotonicStage({ ...awaiting, revision: 2 }, awaiting);
    assert.equal(oldRevision.revision, 2);
    assert.equal(oldRevision.status, "awaiting_approval");

    const parent = mergeMonotonicProject(
      { currentStage: 4, currentStageId: "planning", status: "in_progress" },
      { currentStage: 3, currentStageId: "materials_prep", status: "awaiting_approval" }
    );
    assert.equal(parent.currentStage, 4);
    assert.equal(parent.currentStageId, "planning");

    const state = createSimulation({ approvalRequiredOverride: true });
    reportValidatedResult(state);
    const first = submitDecision(state, "approved");
    const requestCount = state.requests.size;
    assert.throws(() => submitDecision(state, "approved"), /stage_not_approvable/);
    assert.equal(state.requests.size, requestCount);
    assert.equal(state.workflowReceipts.size, 1);
    state.workflowReceipts.add(first.requestId);
    assert.equal(state.workflowReceipts.size, 1);
  });

  it("preserves the newest retry attempt against stale same-r1 full sync", () => {
    const retrying = {
      stageId: "problem_validate",
      stageNumber: 2,
      revision: 1,
      status: "result_validation_retrying",
      attemptCount: 2,
      maxAttempts: 4,
      retryCount: 2,
      maxRetries: 3,
      nextRetryAt: "2026-08-20T08:02:00.000Z",
      retryable: true,
      failureReason: "problem_validate_problem_signals_insufficient",
    };
    const staleR1 = mergeMonotonicStage(retrying, {
      stageId: "problem_validate",
      stageNumber: 2,
      revision: 1,
      status: "result_validation_failed",
      attemptCount: 1,
      retryCount: 1,
    });
    assert.equal(staleR1.status, "result_validation_retrying");
    assert.equal(staleR1.attemptCount, 2);
    assert.equal(staleR1.retryable, true);

    const retryStarted = mergeMonotonicStage(retrying, {
      ...retrying,
      status: "in_progress",
      retryable: false,
      nextRetryAt: "",
    });
    assert.equal(retryStarted.status, "in_progress");
    assert.equal(retryStarted.attemptCount, 2);
    assert.equal(retryStarted.nextRetryAt, "");

    const projectRetry = mergeMonotonicProject(
      { currentStage: 2, currentStageId: "problem_validate",
        status: "result_validation_retrying", attemptCount: 2, retryCount: 2 },
      { currentStage: 2, currentStageId: "problem_validate",
        status: "in_progress", attemptCount: 1, retryCount: 1 }
    );
    assert.equal(projectRetry.status, "result_validation_retrying");
    assert.equal(projectRetry.attemptCount, 2);
  });
});
