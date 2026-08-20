"use strict";

const assert = require("node:assert/strict");
const { describe, it } = require("node:test");
const { AGENT_STATE, WORK_STATUS, ACTIVITY_STATE } = require("../remote/constants");
const { evaluateStageHealth } = require("../remote/monitoring");
const { pickProjectAllowlist } = require("../sotong24/validate");

describe("operational state contract", () => {
  it("shares explicit pause, stall, and failure states", () => {
    assert.equal(AGENT_STATE.RUNNING_AI, "running_ai");
    assert.equal(AGENT_STATE.PAUSED_QUOTA, "paused_quota");
    assert.equal(AGENT_STATE.STALLED, "stalled");
    assert.equal(WORK_STATUS.AI_PROCESS_FAILED, "ai_process_failed");
    assert.equal(WORK_STATUS.RESULT_VALIDATION_FAILED, "result_validation_failed");
    assert.equal(WORK_STATUS.STAGE_TRANSITION_FAILED, "stage_transition_failed");
    assert.equal(ACTIVITY_STATE.PAUSED_QUOTA, "paused_quota");
  });

  it("does not display a quota pause as Codex running or zero usage", () => {
    const result = evaluateStageHealth({
      job: { status: WORK_STATUS.PAUSED_QUOTA },
      stage: { status: WORK_STATUS.PAUSED_QUOTA, errorMessage: "quota_exhausted" },
      agent: { state: AGENT_STATE.PAUSED_QUOTA },
      policy: {},
    });
    assert.equal(result.state, "paused_quota");
    assert.equal(result.reason, "ai_quota_exhausted");
    assert.equal(result.shouldNotify, false);
  });

  it("persists explicit TEST lane markers and rejects a mismatch", () => {
    const now = "2026-08-20T00:00:00.000Z";
    const test = pickProjectAllowlist({
      projectId: "wi_test_na_contract_sync",
      productType: "ebook",
      title: "fixture",
      currentStage: 1,
      totalStages: 18,
      status: "in_progress",
      environment: "test",
      isTest: true,
    }, { serverNowIso: now });
    assert.equal(test.environment, "test");
    assert.equal(test.isTest, true);

    assert.throws(() => pickProjectAllowlist({
      projectId: "wi_test_bad_lane",
      productType: "ebook",
      environment: "production",
      isTest: false,
    }, { serverNowIso: now }), /environment_isTest_mismatch/);
  });
});
