"use strict";

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { handleApiRequest } = require("../remote/router");
const { createMemoryDb } = require("../remote/memory_db");
const { COL } = require("../remote/constants");

function mockRes() {
  return {
    statusCode: 0,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
    set() {
      return this;
    },
    send(payload) {
      this.body = payload;
      return this;
    },
  };
}

function mockReq({ path, body, headers = {}, method = "POST" }) {
  const h = {};
  for (const [k, v] of Object.entries(headers)) h[k.toLowerCase()] = v;
  return {
    method,
    path,
    url: path,
    body,
    rawBody: Buffer.from(JSON.stringify(body || {})),
    get(name) {
      return h[String(name).toLowerCase()] || "";
    },
  };
}

async function control(db, path, body, uid = "user_a") {
  const res = mockRes();
  const req = mockReq({
    path,
    body,
    headers: { Authorization: "Bearer uid:test" },
  });
  await handleApiRequest(req, res, {
    db,
    verifyIdToken: async () => ({ uid, email: "t@test.com" }),
  });
  return res;
}

describe("stall follow-up contract", () => {
  let db;

  beforeEach(() => {
    db = createMemoryDb();
  });

  function seedJob({ jobId = "job_stall_1", iid = "wi_plan_stall", stageId = "app_design_system" } = {}) {
    const agentId = "agent_9830758291f9c64e";
    db.store.set(`${COL.AGENTS}/${agentId}`, {
      agentId,
      ownerUid: "user_a",
      state: "running",
      enabled: true,
      lastHeartbeatAt: new Date().toISOString(),
      currentJobId: jobId,
    });
    db.store.set(`${COL.JOBS}/${jobId}`, {
      jobId,
      ownerUid: "user_a",
      instructionId: iid,
      assignedAgentId: agentId,
      status: "stalled",
      currentStage: stageId,
      recoveryAttempt: 2,
      maxRecoveryAttempts: 3,
    });
    db.store.set(`${COL.JOBS}/${jobId}/stages/${stageId}`, {
      stageId,
      status: "stalled",
      recoveryAttempt: 2,
      activityState: "waiting_for_cursor",
      executorKind: "cursor",
    });
    db.store.set(`${COL.JOBS}/${jobId}/commands/cmd_start`, {
      commandId: "cmd_start",
      type: "START_JOB",
      payload: {
        instructionId: iid,
        aiExecution: { worker: "cursor" },
      },
    });
    db.store.set(`${COL.PROJECTS}/${iid}`, {
      projectId: iid,
      ownerUid: "user_a",
      currentStageId: stageId,
      status: "stalled",
    });
    db.store.set(`${COL.PROJECTS}/${iid}/stages/${stageId}`, {
      stageId,
      status: "stalled",
      recoveryAttempt: 2,
    });
    return { jobId, iid, stageId, agentId };
  }

  it("recheck-status returns agent/worker/heartbeat diagnostic", async () => {
    const { jobId, iid, stageId } = seedJob();
    const res = await control(db, "/api/control/recheck-status", {
      jobId,
      instructionId: iid,
      projectId: iid,
      stageId,
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.state, "ok");
    assert.equal(res.body.jobId, jobId);
    assert.equal(res.body.effectiveWorker, "cursor");
    assert.ok(res.body.heartbeatAt);
  });

  it("pause-job blocks dispatch and is idempotent", async () => {
    const { jobId, iid, stageId } = seedJob();
    const first = await control(db, "/api/control/pause-job", {
      jobId,
      instructionId: iid,
      projectId: iid,
      stageId,
    });
    assert.equal(first.statusCode, 200);
    assert.equal(first.body.state, "paused");
    assert.equal(first.body.idempotent, false);
    const job = db.store.get(`${COL.JOBS}/${jobId}`);
    assert.equal(job.dispatchBlocked, true);
    assert.equal(job.recoveryState, "safe_stopped");
    const duplicate = await control(db, "/api/control/pause-job", {
      jobId,
      instructionId: iid,
      projectId: iid,
      stageId,
    });
    assert.equal(duplicate.statusCode, 200);
    assert.equal(duplicate.body.idempotent, true);
  });

  it("recovery-once is idempotent and blocks when paused", async () => {
    const { jobId, iid, stageId } = seedJob();
    const first = await control(db, "/api/control/recovery-once", {
      jobId,
      instructionId: iid,
      stageId,
    });
    assert.equal(first.statusCode, 200);
    assert.equal(first.body.state, "recovery_requested");
    assert.equal(first.body.idempotent, false);
    const stage = db.store.get(`${COL.JOBS}/${jobId}/stages/${stageId}`);
    assert.equal(stage.manualRecoveryUsed, true);
    const duplicate = await control(db, "/api/control/recovery-once", {
      jobId,
      instructionId: iid,
      stageId,
    });
    assert.equal(duplicate.statusCode, 200);
    assert.equal(duplicate.body.idempotent, true);
    await control(db, "/api/control/pause-job", {
      jobId,
      instructionId: iid,
      projectId: iid,
      stageId,
    });
    const blocked = await control(db, "/api/control/recovery-once", {
      jobId,
      instructionId: iid,
      stageId,
    });
    assert.equal(blocked.statusCode, 409);
    assert.equal(blocked.body.error, "paused");
  });

  it("get-diagnostics returns cancelDiagnostics by instructionId", async () => {
    const iid = "wi_plan_diag";
    db.store.set("cancelDiagnostics/op_diag_1", {
      operationId: "op_diag_1",
      ownerUid: "user_a",
      instructionId: iid,
      jobId: "job_diag",
      summary: "test snapshot",
    });
    const res = await control(db, "/api/control/get-diagnostics", {
      instructionId: iid,
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.diagnostics.length, 1);
    assert.equal(res.body.diagnostics[0].instructionId, iid);
  });
});
