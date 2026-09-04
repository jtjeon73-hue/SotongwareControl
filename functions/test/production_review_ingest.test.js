"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { createMemoryDb } = require("../remote/memory_db");
const { COL } = require("../remote/constants");
const {
  STATUS_COLLECTION,
  sanitizeAndValidate,
  resolveNotificationEventType,
  shouldSuppressNotification,
  applyProductionReviewStatus,
} = require("../remote/production_review_ingest");
const { handleHeartbeat } = require("../remote/handlers");

function baseEnvelope(overrides = {}) {
  return {
    schemaVersion: 1,
    eventId: "prse_test_r1_001",
    instructionId: "wi_test_cursor_app_step15_1788441053773",
    projectId: "farm_safety_check",
    jobId: "",
    artifactType: "app",
    displayTitle: "농작업 안전 점검",
    revision: "R1",
    stageId: "app_device_review_prep",
    stageOrder: 15,
    stageStatus: "completed",
    verifiedThroughStep: 15,
    lastVerifiedStage: "app_device_review_prep",
    productionStatus:
      "technical_validation_completed_owner_changes_requested",
    updatedAt: "2026-09-04T12:00:00.000Z",
    emittedAt: "2026-09-04T12:00:00.000Z",
    sequence: 15,
    technicalValidation: {
      status: "completed",
      completed: true,
      validatorResult: "pass",
      artifactKind: "apk",
      artifactSha256: "a".repeat(64),
      completedAt: "2026-09-04T08:00:00.000Z",
    },
    ownerReview: {
      decision: "changes_requested",
      revision: "R1",
      step16Blocked: true,
      nextAllowedAction: "R2 revision only",
      findingCount: 11,
      blockerCount: 0,
      highCount: 5,
      decisionRef: "",
      reviewedAt: "2026-09-04T08:00:00.000Z",
    },
    execution: {
      agentState: "paused",
      currentJobId: "",
      paused: true,
      recoveryState: "",
      permitState: "none",
      worker: "cursor",
      heartbeatAt: "2026-09-04T08:00:00.000Z",
      terminalBlockCount: 3,
    },
    readiness: {
      technicalValidationCompleted: true,
      ownerReviewRequired: false,
      revisionRequired: true,
      revisionReady: true,
      registrationEligible: false,
      externalPublicationAllowed: false,
    },
    problem: {
      code: "",
      severity: "",
      userSummary: "",
      recommendedActions: [],
      occurredAt: "",
    },
    userLabelKo: "기술검증 완료 · 사용자 보완요청 · R2 준비 대기",
    nextActionKo: "R2 초안 준비",
    initialSync: false,
    syncKind: "transition",
    contentFingerprint: "fp_app_r1_changes",
    ...overrides,
  };
}

function seedAgent(db, agentId = "agent_test") {
  const ref = db.collection(COL.AGENTS).doc(agentId);
  return ref.set({
    agentId,
    ownerUid: "user_a",
    state: "idle",
    updatedAt: "2026-09-04T12:00:00.000Z",
  }).then(() => ({
    agentId,
    agentRef: ref,
  }));
}

describe("production_review_ingest", () => {
  it("baseline initialSync → applied, notificationEnqueued=false", async () => {
    const db = createMemoryDb();
    const enqueueCalls = [];
    const envelope = baseEnvelope({
      initialSync: true,
      syncKind: "baseline",
      eventId: "prse_baseline_001",
    });

    const result = await applyProductionReviewStatus(db, envelope, {
      agentId: "agent_x",
      enqueueFn: async (_db, data) => {
        enqueueCalls.push(data);
        return { created: true };
      },
    });

    assert.equal(result.ok, true);
    assert.equal(result.applied, true);
    assert.equal(result.notificationEnqueued, false);
    assert.equal(enqueueCalls.length, 0);

    const stored = db.store.get(
      `${STATUS_COLLECTION}/${envelope.instructionId}`
    );
    assert.ok(stored);
    assert.equal(stored.syncKind, "baseline");
    assert.equal(stored.initialSync, true);
  });

  it("duplicate event → duplicate, no second notification", async () => {
    const db = createMemoryDb();
    const enqueueCalls = [];
    const enqueueFn = async (_db, data) => {
      enqueueCalls.push(data);
      return { created: true };
    };
    const envelope = baseEnvelope({
      syncKind: "transition",
      initialSync: false,
      eventId: "prse_dup_001",
    });

    const first = await applyProductionReviewStatus(db, envelope, {
      agentId: "agent_x",
      enqueueFn,
    });
    assert.equal(first.applied, true);
    assert.equal(first.notificationEnqueued, true);
    assert.equal(enqueueCalls.length, 1);

    const second = await applyProductionReviewStatus(db, envelope, {
      agentId: "agent_x",
      enqueueFn,
    });
    assert.equal(second.ok, true);
    assert.equal(second.duplicate, true);
    assert.equal(second.applied, false);
    assert.equal(second.notificationEnqueued, false);
    assert.equal(enqueueCalls.length, 1);
  });

  it("revision rollback → rejected", async () => {
    const db = createMemoryDb();
    await applyProductionReviewStatus(db, baseEnvelope({
      eventId: "prse_roll_base",
      syncKind: "baseline",
      initialSync: true,
    }), { enqueueFn: async () => ({ created: false }) });

    const result = await applyProductionReviewStatus(
      db,
      baseEnvelope({
        eventId: "prse_roll_bad",
        revision: "R0",
        syncKind: "transition",
        initialSync: false,
        sequence: 99,
        emittedAt: "2026-09-04T13:00:00.000Z",
      }),
      { enqueueFn: async () => ({ created: true }) }
    );

    assert.equal(result.ok, false);
    assert.equal(result.rejected, true);
    assert.equal(result.code, "PRSE_REVISION_ROLLBACK");
    assert.equal(result.notificationEnqueued, false);
  });

  it("transition changes_requested → notificationEnqueued=true (mock enqueue)", async () => {
    const db = createMemoryDb();
    await seedAgent(db, "agent_notify");
    const enqueueCalls = [];
    const envelope = baseEnvelope({
      eventId: "prse_transition_cr",
      syncKind: "transition",
      initialSync: false,
      contentFingerprint: "fp_new_transition",
    });

    // Seed project so merge path is exercised without wiping fields.
    await db.collection(COL.PROJECTS).doc(envelope.instructionId).set({
      projectId: envelope.instructionId,
      title: "keep-me",
      otherField: "preserved",
    });

    const result = await applyProductionReviewStatus(db, envelope, {
      agentId: "agent_notify",
      enqueueFn: async (_db, data) => {
        enqueueCalls.push(data);
        return { created: true };
      },
    });

    assert.equal(result.ok, true);
    assert.equal(result.applied, true);
    assert.equal(result.notificationEnqueued, true);
    assert.equal(enqueueCalls.length, 1);
    assert.equal(
      enqueueCalls[0].eventType,
      "owner_review_changes_requested"
    );

    const project = db.store.get(
      `${COL.PROJECTS}/${envelope.instructionId}`
    );
    assert.equal(project.otherField, "preserved");
    assert.equal(project.title, "keep-me");
    assert.ok(project.productionReviewStatus);
    assert.equal(
      project.productionReviewStatus.ownerReview.decision,
      "changes_requested"
    );
  });

  it("sensitive field rejected", async () => {
    const db = createMemoryDb();
    const result = await applyProductionReviewStatus(
      db,
      baseEnvelope({
        eventId: "prse_sensitive",
        apiKey: "secret-value",
      }),
      { enqueueFn: async () => ({ created: true }) }
    );
    assert.equal(result.ok, false);
    assert.equal(result.rejected, true);
    assert.equal(result.code, "PRSE_SENSITIVE_FIELD");

    const validation = sanitizeAndValidate(
      baseEnvelope({
        technicalValidation: {
          status: "completed",
          completed: true,
          validatorResult: "C:\\Users\\secret\\build.log",
          artifactKind: "apk",
          artifactSha256: "a".repeat(64),
          completedAt: "2026-09-04T08:00:00.000Z",
        },
      }),
      null
    );
    assert.equal(validation.ok, false);
    assert.equal(validation.code, "PRSE_SENSITIVE_FIELD");
  });

  it("heartbeat continues when envelope rejected (unit-level)", async () => {
    const db = createMemoryDb();
    const ctx = await seedAgent(db, "agent_hb");
    const body = {
      state: "idle",
      protocolVersion: "1.0",
      productionReviewStatus: {
        schemaVersion: 1,
        eventId: "prse_hb_bad",
        instructionId: "wi_hb",
        secret: "should-reject",
        revision: "R1",
      },
    };

    const out = await handleHeartbeat(db, ctx, body);
    assert.deepEqual(out, {});
    const agent = db.store.get(`${COL.AGENTS}/agent_hb`);
    assert.ok(agent.lastHeartbeatAt);
    assert.equal(
      db.store.has(`${STATUS_COLLECTION}/wi_hb`),
      false
    );
  });

  it("shouldSuppressNotification covers baseline and fingerprint", () => {
    const incoming = baseEnvelope({
      initialSync: true,
      syncKind: "baseline",
      contentFingerprint: "fp1",
    });
    assert.equal(
      shouldSuppressNotification({
        incoming,
        stored: null,
        isBaseline: true,
      }),
      true
    );
    assert.equal(
      shouldSuppressNotification({
        incoming: baseEnvelope({
          initialSync: false,
          syncKind: "transition",
          contentFingerprint: "same",
          eventId: "e2",
        }),
        stored: baseEnvelope({
          contentFingerprint: "same",
          eventId: "e1",
        }),
        isBaseline: false,
      }),
      true
    );
  });

  it("resolveNotificationEventType maps changes_requested", () => {
    assert.equal(
      resolveNotificationEventType(baseEnvelope(), null),
      "owner_review_changes_requested"
    );
  });

  it("merges onto projectId when instructionId doc missing", async () => {
    const db = createMemoryDb();
    const envelope = baseEnvelope({
      eventId: "prse_proj_merge",
      syncKind: "baseline",
      initialSync: true,
    });
    await db.collection(COL.PROJECTS).doc(envelope.projectId).set({
      projectId: envelope.projectId,
      keep: true,
    });

    const result = await applyProductionReviewStatus(db, envelope, {
      enqueueFn: async () => ({ created: true }),
    });
    assert.equal(result.applied, true);
    const project = db.store.get(`${COL.PROJECTS}/${envelope.projectId}`);
    assert.equal(project.keep, true);
    assert.ok(project.productionReviewStatus);
  });
});
