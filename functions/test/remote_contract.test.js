"use strict";

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { handleApiRequest } = require("../remote/router");
const { createMemoryDb } = require("../remote/memory_db");
const { sha256Hex } = require("../remote/crypto_util");
const { COL, PROTOCOL_VERSION } = require("../remote/constants");
const {
  finalizeCancelledRun,
  operationId: cancelOperationId,
} = require("../remote/cancellation");
const {
  evaluateStageHealth,
  evaluateActiveJobs,
  enqueueNotification,
  normalizePolicy,
} = require("../remote/monitoring");

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
  };
}

function mockReq({ path, body, headers = {}, method = "POST" }) {
  const h = {};
  for (const [k, v] of Object.entries(headers)) {
    h[k.toLowerCase()] = v;
  }
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

async function call(db, path, body, { token, uid, method = "POST" } = {}) {
  const res = mockRes();
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  const req = mockReq({ path, body, headers, method });
  const deps = {
    db,
    verifyIdToken: async (t) => {
      if (t === "bad") throw new Error("bad");
      if (t.startsWith("uid:")) return { uid: t.slice(4), email: "t@test.com" };
      if (uid) return { uid, email: "t@test.com" };
      return { uid: "user_a", email: "a@test.com" };
    },
  };
  // Control uses Bearer as id token; when uid option set without token prefix
  if (uid && token && !token.startsWith("uid:")) {
    deps.verifyIdToken = async () => ({ uid, email: "t@test.com" });
  }
  await handleApiRequest(req, res, deps);
  return res;
}

async function control(db, path, body, uid = "user_a") {
  return call(db, path, body, { token: `uid:${uid}`, uid });
}

describe("remote agent contract V1", () => {
  let db;

  beforeEach(() => {
    db = createMemoryDb();
  });

  async function pairAndEnroll(uid = "user_a") {
    const pair = await control(db, "/api/control/create-pairing", {}, uid);
    assert.equal(pair.statusCode, 200);
    const enroll = await call(db, "/api/agent/enroll", {
      pairingCode: pair.body.pairingCode,
      deviceName: "PC-Test",
      appVersion: "Sotong24Work/2.0",
      protocolVersion: PROTOCOL_VERSION,
    });
    assert.equal(enroll.statusCode, 200);
    return {
      pairingCode: pair.body.pairingCode,
      agentId: enroll.body.agentId,
      agentToken: enroll.body.agentToken,
    };
  }

  // A. Pairing
  it("1-3 pairing create + enroll + token", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    assert.ok(agentId.startsWith("agent_"));
    assert.ok(agentToken.length > 20);
    const agent = db.store.get(`${COL.AGENTS}/${agentId}`);
    assert.equal(agent.ownerUid, "user_a");
    assert.equal(agent.enabled, true);
    assert.ok(agent.tokenHash);
    assert.notEqual(agent.tokenHash, agentToken);
    assert.ok(db.store.has(`${COL.AGENT_TOKENS}/${sha256Hex(agentToken)}`));
  });

  it("4 reuse pairing code fails", async () => {
    const { pairingCode } = await pairAndEnroll();
    const again = await call(db, "/api/agent/enroll", {
      pairingCode,
      deviceName: "x",
      protocolVersion: "1.0",
    });
    assert.equal(again.statusCode, 403);
  });

  it("5 expired pairing fails", async () => {
    const pair = await control(db, "/api/control/create-pairing", {});
    const sessionId = pair.body.sessionId;
    const s = db.store.get(`${COL.PAIRING}/${sessionId}`);
    s.expiresAt = new Date(Date.now() - 1000).toISOString();
    db.store.set(`${COL.PAIRING}/${sessionId}`, s);
    const enroll = await call(db, "/api/agent/enroll", {
      pairingCode: pair.body.pairingCode,
      deviceName: "x",
      protocolVersion: "1.0",
    });
    assert.equal(enroll.statusCode, 403);
  });

  it("6 bad pairing code fails", async () => {
    const res = await call(db, "/api/agent/enroll", {
      pairingCode: "NOPE1234",
      deviceName: "x",
      protocolVersion: "1.0",
    });
    assert.equal(res.statusCode, 403);
  });

  // B. Auth
  it("7 missing token → 401", async () => {
    const { agentId } = await pairAndEnroll();
    const res = await call(db, "/api/agent/heartbeat", {
      agentId,
      state: "idle",
      protocolVersion: "1.0",
    });
    assert.equal(res.statusCode, 401);
  });

  it("8 wrong token → 401", async () => {
    const { agentId } = await pairAndEnroll();
    const res = await call(
      db,
      "/api/agent/heartbeat",
      { agentId, state: "idle", protocolVersion: "1.0" },
      { token: "totally-wrong" }
    );
    assert.equal(res.statusCode, 401);
  });

  it("9 agentId mismatch → 403", async () => {
    const { agentToken } = await pairAndEnroll();
    const res = await call(
      db,
      "/api/agent/heartbeat",
      { agentId: "agent_other", state: "idle", protocolVersion: "1.0" },
      { token: agentToken }
    );
    assert.equal(res.statusCode, 403);
  });

  it("10 disabled agent → 403", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const a = db.store.get(`${COL.AGENTS}/${agentId}`);
    a.enabled = false;
    db.store.set(`${COL.AGENTS}/${agentId}`, a);
    const res = await call(
      db,
      "/api/agent/heartbeat",
      { agentId, state: "idle", protocolVersion: "1.0" },
      { token: agentToken }
    );
    assert.equal(res.statusCode, 403);
  });

  // C. Heartbeat
  it("11-12 heartbeat updates lastHeartbeatAt", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const res = await call(
      db,
      "/api/agent/heartbeat",
      {
        agentId,
        state: "idle",
        deviceName: "PC",
        appVersion: "2.0",
        protocolVersion: "1.0",
        currentJobId: "",
        currentStage: "",
        timestamp: "2020-01-01T00:00:00.000Z",
      },
      { token: agentToken }
    );
    assert.equal(res.statusCode, 200);
    const a = db.store.get(`${COL.AGENTS}/${agentId}`);
    assert.ok(a.lastHeartbeatAt);
    assert.notEqual(a.lastHeartbeatAt, "2020-01-01T00:00:00.000Z");
    assert.equal(a.state, "idle");
  });

  it("12b heartbeat persists allowlisted aiUsage.codex", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const res = await call(
      db,
      "/api/agent/heartbeat",
      {
        agentId,
        state: "idle",
        protocolVersion: "1.0",
        aiUsage: {
          codex: {
            status: "ok",
            collectedAt: "2026-08-18T02:00:00.000Z",
            planType: "plus",
            weekly: {
              usedPercent: 18,
              remainingPercent: 82,
              windowDurationMins: 10080,
              resetsAt: "2026-08-20T14:26:00.000Z",
              resetsAtIso: "2026-08-20T14:26:00.000Z",
            },
            accessToken: "must-not-persist",
          },
        },
      },
      { token: agentToken }
    );
    assert.equal(res.statusCode, 200);
    const a = db.store.get(`${COL.AGENTS}/${agentId}`);
    assert.equal(a.aiUsage.codex.status, "ok");
    assert.equal(a.aiUsage.codex.planType, "plus");
    assert.equal(a.aiUsage.codex.weekly.usedPercent, 18);
    assert.equal(a.aiUsage.codex.weekly.remainingPercent, 82);
    assert.equal(a.aiUsage.codex.weekly.windowDurationMins, 10080);
    assert.ok(!("accessToken" in a.aiUsage.codex));
  });

  it("12c malformed aiUsage does not fail heartbeat", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const res = await call(
      db,
      "/api/agent/heartbeat",
      {
        agentId,
        state: "idle",
        protocolVersion: "1.0",
        aiUsage: {
          codex: {
            status: "not_a_real_status",
            weekly: { usedPercent: 18 },
          },
        },
      },
      { token: agentToken }
    );
    assert.equal(res.statusCode, 200);
    const a = db.store.get(`${COL.AGENTS}/${agentId}`);
    assert.ok(!a.aiUsage);
  });

  // D. START_JOB lifecycle
  it("13-18 create-job start-job pull claim", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const job = await control(db, "/api/control/create-job", {
      title: "Ebook job",
      type: "ebook",
      assignedAgentId: agentId,
      totalStages: 18,
    });
    assert.equal(job.statusCode, 200);
    const jobId = job.body.jobId;

    const start = await control(db, "/api/control/start-job", {
      jobId,
      payload: { schemaVersion: "1.0", title: "WI" },
    });
    assert.equal(start.statusCode, 200);
    const commandId = start.body.commandId;

    const pull = await call(
      db,
      "/api/agent/pull",
      { agentId, protocolVersion: "1.0", limit: 5 },
      { token: agentToken }
    );
    assert.equal(pull.statusCode, 200);
    assert.equal(pull.body.commands.length, 1);
    assert.equal(pull.body.commands[0].type, "START_JOB");
    assert.equal(pull.body.commands[0].status, "queued");

    const claim = await call(
      db,
      "/api/agent/claim",
      { agentId, commandId, jobId, protocolVersion: "1.0" },
      { token: agentToken }
    );
    assert.equal(claim.statusCode, 200);
    const cmd = db.store.get(`${COL.JOBS}/${jobId}/commands/${commandId}`);
    assert.equal(cmd.status, "claimed");
    assert.ok(cmd.claimedAt);
  });

  // E. Idempotency
  it("19 re-claim same command is safe", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const job = await control(db, "/api/control/create-job", {
      title: "j",
      assignedAgentId: agentId,
    });
    const start = await control(db, "/api/control/start-job", {
      jobId: job.body.jobId,
      payload: {},
    });
    const commandId = start.body.commandId;
    const jobId = job.body.jobId;
    await call(
      db,
      "/api/agent/claim",
      { agentId, commandId, jobId, protocolVersion: "1.0" },
      { token: agentToken }
    );
    const again = await call(
      db,
      "/api/agent/claim",
      { agentId, commandId, jobId, protocolVersion: "1.0" },
      { token: agentToken }
    );
    assert.equal(again.statusCode, 200);
    assert.equal(again.body.alreadyClaimed, true);
  });

  it("20 complete then claim rejected", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const job = await control(db, "/api/control/create-job", {
      title: "j",
      assignedAgentId: agentId,
    });
    const start = await control(db, "/api/control/start-job", {
      jobId: job.body.jobId,
      payload: {},
    });
    const { commandId } = start.body;
    const jobId = job.body.jobId;
    await call(
      db,
      "/api/agent/claim",
      { agentId, commandId, jobId, protocolVersion: "1.0" },
      { token: agentToken }
    );
    await call(
      db,
      "/api/agent/complete",
      { agentId, commandId, jobId, summary: "ok", protocolVersion: "1.0" },
      { token: agentToken }
    );
    const claim = await call(
      db,
      "/api/agent/claim",
      { agentId, commandId, jobId, protocolVersion: "1.0" },
      { token: agentToken }
    );
    assert.equal(claim.statusCode, 409);
  });

  // F. Ownership
  it("21 other uid cannot start job", async () => {
    const { agentId } = await pairAndEnroll("user_a");
    const job = await control(
      db,
      "/api/control/create-job",
      { title: "j", assignedAgentId: agentId },
      "user_a"
    );
    const bad = await control(
      db,
      "/api/control/start-job",
      { jobId: job.body.jobId, payload: {} },
      "user_b"
    );
    assert.equal(bad.statusCode, 403);
  });

  // G. Report
  it("22-24 report job/stage/error", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const job = await control(db, "/api/control/create-job", {
      title: "j",
      assignedAgentId: agentId,
    });
    const jobId = job.body.jobId;
    const r1 = await call(
      db,
      "/api/agent/report-job",
      { agentId, jobId, status: "running", protocolVersion: "1.0" },
      { token: agentToken }
    );
    assert.equal(r1.statusCode, 200);
    const r2 = await call(
      db,
      "/api/agent/report-stage",
      {
        agentId,
        jobId,
        stageId: "launch",
        status: "waiting_approval",
        criteriaMet: true,
        approvalRequired: true,
        revision: 1,
        protocolVersion: "1.0",
      },
      { token: agentToken }
    );
    assert.equal(r2.statusCode, 200);
    assert.ok(db.store.get(`${COL.JOBS}/${jobId}/stages/launch`));
    assert.equal(
      db.store.get(`${COL.JOBS}/${jobId}/stages/launch`).status,
      "waiting_approval"
    );
    assert.equal(db.store.get(`${COL.JOBS}/${jobId}`).status, "waiting_approval");
    const r3 = await call(
      db,
      "/api/agent/report-error",
      { agentId, jobId, code: "x", message: "y", protocolVersion: "1.0" },
      { token: agentToken }
    );
    assert.equal(r3.statusCode, 200);
    const agent = db.store.get(`${COL.AGENTS}/${agentId}`);
    assert.equal(agent.state, "error");
  });

  // H. Failures
  it("25 invalid payload", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const res = await call(
      db,
      "/api/agent/claim",
      { agentId, protocolVersion: "1.0" },
      { token: agentToken }
    );
    assert.equal(res.statusCode, 400);
  });

  it("26 nonexistent job report", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const res = await call(
      db,
      "/api/agent/report-job",
      { agentId, jobId: "job_missing", status: "running", protocolVersion: "1.0" },
      { token: agentToken }
    );
    assert.equal(res.statusCode, 404);
  });

  it("27 create-job nonexistent agent", async () => {
    const res = await control(db, "/api/control/create-job", {
      title: "j",
      assignedAgentId: "agent_nope",
    });
    assert.equal(res.statusCode, 404);
  });

  it("28 malformed authorization", async () => {
    const res = mockRes();
    const req = mockReq({
      path: "/api/agent/pull",
      body: { protocolVersion: "1.0" },
      headers: { Authorization: "Token nope" },
    });
    await handleApiRequest(req, res, { db, verifyIdToken: async () => ({}) });
    assert.equal(res.statusCode, 401);
  });

  it("29 protocol version incompatible", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    const res = await call(
      db,
      "/api/agent/pull",
      { agentId, protocolVersion: "9.9", limit: 5 },
      { token: agentToken }
    );
    assert.equal(res.statusCode, 400);
    assert.equal(res.body.error, "protocol_version_incompatible");
  });

  it("GET method rejected", async () => {
    const res = await call(db, "/api/agent/pull", {}, { method: "GET" });
    assert.equal(res.statusCode, 405);
  });

  async function heartbeat(agentId, agentToken) {
    const res = await call(
      db,
      "/api/agent/heartbeat",
      { agentId, state: "idle", protocolVersion: PROTOCOL_VERSION },
      { token: agentToken }
    );
    assert.equal(res.statusCode, 200);
  }

  it("deliver-instruction creates job+START_JOB once", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    await heartbeat(agentId, agentToken);
    const first = await control(db, "/api/control/deliver-instruction", {
      instructionId: "wi_plan_1786083242850",
      title: "AI 학습 도우미 활용법 전자책",
      type: "ebook",
      assignedAgentId: agentId,
      payload: { instructionId: "wi_plan_1786083242850", businessIdea: "AI 학습 도우미 활용법 전자책" },
    });
    assert.equal(first.statusCode, 200);
    assert.ok(first.body.jobId);
    assert.ok(first.body.commandId);
    assert.equal(first.body.outcome, "created");

    const again = await control(db, "/api/control/deliver-instruction", {
      instructionId: "wi_plan_1786083242850",
      title: "AI 학습 도우미 활용법 전자책",
      type: "ebook",
      assignedAgentId: agentId,
      payload: { instructionId: "wi_plan_1786083242850" },
    });
    assert.equal(again.statusCode, 200);
    assert.equal(again.body.jobId, first.body.jobId);
    assert.equal(again.body.commandId, first.body.commandId);
    assert.equal(again.body.idempotent, true);

    const jobDoc = db.store.get(`${COL.JOBS}/${first.body.jobId}`);
    assert.equal(jobDoc.instructionId, "wi_plan_1786083242850");
  });

  it("deliver-instruction repairs START_JOB only", async () => {
    const { agentId, agentToken } = await pairAndEnroll();
    await heartbeat(agentId, agentToken);
    const created = await control(db, "/api/control/create-job", {
      title: "orphan",
      type: "ebook",
      assignedAgentId: agentId,
      instructionId: "wi_plan_orphan_cmd",
    });
    assert.equal(created.statusCode, 200);
    const repaired = await control(db, "/api/control/deliver-instruction", {
      instructionId: "wi_plan_orphan_cmd",
      title: "orphan",
      assignedAgentId: agentId,
      payload: { instructionId: "wi_plan_orphan_cmd" },
    });
    assert.equal(repaired.statusCode, 200);
    assert.equal(repaired.body.jobId, created.body.jobId);
    assert.equal(repaired.body.outcome, "command_repaired");
    assert.ok(repaired.body.commandId);
  });

  it("deliver-instruction rejects offline agent", async () => {
    const { agentId } = await pairAndEnroll();
    const res = await control(db, "/api/control/deliver-instruction", {
      instructionId: "wi_plan_offline",
      title: "t",
      assignedAgentId: agentId,
      payload: { instructionId: "wi_plan_offline" },
    });
    assert.equal(res.statusCode, 409);
    assert.equal(res.body.error, "agent_offline");
  });

  it("create-job with instructionId is idempotent", async () => {
    const { agentId } = await pairAndEnroll();
    const a = await control(db, "/api/control/create-job", {
      title: "t",
      assignedAgentId: agentId,
      instructionId: "wi_plan_idem",
    });
    const b = await control(db, "/api/control/create-job", {
      title: "t2",
      assignedAgentId: agentId,
      instructionId: "wi_plan_idem",
    });
    assert.equal(a.body.jobId, b.body.jobId);
    assert.equal(b.body.idempotent, true);
  });

  async function monitoringJob(instructionId = "wi_plan_monitoring") {
    const { agentId, agentToken } = await pairAndEnroll();
    const created = await control(db, "/api/control/create-job", {
      title: "monitoring",
      type: "ebook",
      assignedAgentId: agentId,
      instructionId,
    });
    return { agentId, agentToken, jobId: created.body.jobId, instructionId };
  }

  it("stage start uses server time even when a ready document already exists", async () => {
    const env = await monitoringJob("wi_plan_monitor_start");
    db.store.set(`${COL.JOBS}/${env.jobId}/stages/idea_clarify`, {
      stageId: "idea_clarify", status: "ready", startedAt: null,
    });
    const res = await call(db, "/api/agent/report-stage", {
      jobId: env.jobId,
      stageId: "idea_clarify",
      stageNumber: 1,
      stageName: "아이디어 정리",
      status: "running",
      startedAt: "2020-01-01T00:00:00.000Z",
    }, { token: env.agentToken });
    assert.equal(res.statusCode, 200);
    const stage = db.store.get(`${COL.JOBS}/${env.jobId}/stages/idea_clarify`);
    assert.ok(stage.startedAt);
    assert.notEqual(stage.startedAt, "2020-01-01T00:00:00.000Z");
    assert.equal(stage.lastActivityAt, stage.updatedAt);
  });

  it("explicit work activity updates lastActivityAt but heartbeat does not", async () => {
    const env = await monitoringJob("wi_plan_monitor_activity");
    const activity = await call(db, "/api/agent/report-activity", {
      jobId: env.jobId,
      instructionId: env.instructionId,
      stageId: "idea_clarify",
      stageNumber: 1,
      revision: 1,
      activityState: "codex_running",
      activityType: "executor_state_change",
      progress: 5,
      timestamp: "2020-01-01T00:00:00.000Z",
    }, { token: env.agentToken });
    assert.equal(activity.statusCode, 200);
    const key = `${COL.JOBS}/${env.jobId}/stages/idea_clarify`;
    const before = db.store.get(key).lastActivityAt;
    assert.notEqual(before, "2020-01-01T00:00:00.000Z");
    await call(db, "/api/agent/heartbeat", {
      agentId: env.agentId,
      state: "running",
      currentJobId: env.jobId,
      currentStage: "idea_clarify",
      protocolVersion: PROTOCOL_VERSION,
    }, { token: env.agentToken });
    assert.equal(db.store.get(key).lastActivityAt, before);
  });

  it("mirrors validation retry metadata and clears waiting state on retry start", async () => {
    const env = await monitoringJob("wi_plan_validation_retry");
    db.store.set(`${COL.PROJECTS}/${env.instructionId}`, {
      projectId: env.instructionId,
      currentStageId: "problem_validate",
      currentStage: 2,
      status: "in_progress",
    });
    const retry = await call(db, "/api/agent/report-activity", {
      jobId: env.jobId,
      instructionId: env.instructionId,
      stageId: "problem_validate",
      stageNumber: 2,
      revision: 1,
      activityState: "validation_retry_waiting",
      activityType: "executor_state_change",
      attemptCount: 1,
      maxAttempts: 4,
      retryCount: 1,
      maxRetries: 3,
      nextRetryAt: "2026-08-20T08:03:00.000Z",
      failureType: "validation",
      failureReason: "problem_validate_problem_signals_insufficient",
      retryable: true,
    }, { token: env.agentToken });
    assert.equal(retry.statusCode, 200);
    const stageKey = `${COL.JOBS}/${env.jobId}/stages/problem_validate`;
    assert.equal(db.store.get(stageKey).retryCount, 1);
    assert.equal(db.store.get(stageKey).retryable, true);
    assert.equal(db.store.get(stageKey).activityState, "validation_retry_waiting");
    assert.equal(
      db.store.get(`${COL.PROJECTS}/${env.instructionId}/stages/problem_validate`).nextRetryAt,
      "2026-08-20T08:03:00.000Z"
    );

    const started = await call(db, "/api/agent/report-stage", {
      jobId: env.jobId,
      stageId: "problem_validate",
      stageNumber: 2,
      revision: 1,
      status: "running",
    }, { token: env.agentToken });
    assert.equal(started.statusCode, 200);
    assert.equal(db.store.get(stageKey).status, "running");
    assert.equal(db.store.get(stageKey).attemptCount, 1);
    assert.equal(db.store.get(stageKey).retryable, false);
    assert.equal(db.store.get(stageKey).nextRetryAt, "");
  });

  it("waiting approval creates one idempotent approval notification", async () => {
    const env = await monitoringJob("wi_plan_monitor_approval");
    db.store.set(`${COL.PROJECTS}/${env.instructionId}`, {
      projectId: env.instructionId,
      currentStageId: "idea_clarify",
      status: "in_progress",
    });
    const body = {
      jobId: env.jobId,
      stageId: "idea_clarify",
      stageNumber: 1,
      stageName: "아이디어 정리",
      revision: 1,
      approvalRequired: true,
      criteriaMet: true,
      status: "waiting_approval",
    };
    const first = await call(db, "/api/agent/report-stage", body, { token: env.agentToken });
    const second = await call(db, "/api/agent/report-stage", body, { token: env.agentToken });
    assert.equal(first.statusCode, 200);
    assert.equal(second.statusCode, 200);
    const events = [...db.store.entries()].filter(([key]) => key.startsWith(`${COL.NOTIFICATION_EVENTS}/`));
    assert.equal(events.length, 1);
    assert.equal(events[0][1].eventType, "approval_required");
    const job = db.store.get(`${COL.JOBS}/${env.jobId}`);
    const jobStage = db.store.get(`${COL.JOBS}/${env.jobId}/stages/idea_clarify`);
    const project = db.store.get(`${COL.PROJECTS}/${env.instructionId}`);
    const projectStage = db.store.get(`${COL.PROJECTS}/${env.instructionId}/stages/idea_clarify`);
    assert.equal(job.status, "waiting_approval");
    assert.equal(job.currentStageCriteriaMet, true);
    assert.equal(jobStage.criteriaMet, true);
    assert.equal(jobStage.approvalRequired, true);
    assert.equal(project.status, "awaiting_approval");
    assert.equal(project.currentStageId, "idea_clarify");
    assert.equal(projectStage.status, "awaiting_approval");
    assert.equal(projectStage.criteriaMet, true);
    assert.equal(projectStage.approvalRequired, true);
    assert.equal(projectStage.revision, 1);
    assert.ok(jobStage.completedAt);
    assert.ok(projectStage.completedAt);
    assert.ok(projectStage.lastActivityAt);
    assert.equal(projectStage.activityState, "approval_preparing");

    const stale = await call(db, "/api/agent/report-stage", {
      ...body,
      status: "running",
      criteriaMet: false,
      approvalRequired: false,
    }, { token: env.agentToken });
    assert.equal(stale.statusCode, 200);
    assert.equal(
      db.store.get(`${COL.JOBS}/${env.jobId}/stages/idea_clarify`).status,
      "waiting_approval"
    );
    assert.equal(
      db.store.get(`${COL.PROJECTS}/${env.instructionId}/stages/idea_clarify`).status,
      "awaiting_approval"
    );
    assert.equal(db.store.get(`${COL.PROJECTS}/${env.instructionId}`).status, "awaiting_approval");
  });

  it("waiting approval rejects incomplete criteria before writing", async () => {
    const env = await monitoringJob("wi_plan_monitor_incomplete");
    const res = await call(db, "/api/agent/report-stage", {
      jobId: env.jobId,
      stageId: "problem_validate",
      stageNumber: 2,
      approvalRequired: true,
      criteriaMet: false,
      status: "waiting_approval",
    }, { token: env.agentToken });
    assert.equal(res.statusCode, 409);
    assert.equal(
      db.store.has(`${COL.JOBS}/${env.jobId}/stages/problem_validate`),
      false
    );
  });

  it("revision r2 completion uses a distinct one-time notification", async () => {
    const env = await monitoringJob("wi_plan_monitor_r2");
    const body = {
      jobId: env.jobId,
      stageId: "problem_validation",
      stageNumber: 2,
      stageName: "고객 문제 검증",
      revision: 2,
      approvalRequired: true,
      criteriaMet: true,
      status: "waiting_approval",
    };
    await call(db, "/api/agent/report-stage", body, { token: env.agentToken });
    await call(db, "/api/agent/report-stage", body, { token: env.agentToken });
    const events = [...db.store.values()].filter((v) => v.eventType === "revision_completed");
    assert.equal(events.length, 1);
    assert.match(events[0].body, /r2/);
  });

  it("health detects inactivity and offline without changing a long-running job", () => {
    const nowMs = Date.parse("2026-08-19T01:00:00.000Z");
    const policy = normalizePolicy({
      offlineAfterSeconds: 600,
      noActivityAfterSeconds: 300,
      defaultExpectedMaxSeconds: 120,
    });
    const job = { status: "running", startedAt: "2026-08-19T00:00:00.000Z" };
    const stage = {
      stageId: "idea_clarify",
      status: "running",
      startedAt: "2026-08-19T00:00:00.000Z",
      lastActivityAt: "2026-08-19T00:58:00.000Z",
    };
    const delayed = evaluateStageHealth({
      job,
      stage,
      agent: { state: "running", lastHeartbeatAt: "2026-08-19T00:59:30.000Z" },
      policy,
      nowMs,
    });
    assert.equal(delayed.state, "delayed");
    assert.equal(delayed.shouldNotify, false);
    assert.equal(job.status, "running");

    const inactive = evaluateStageHealth({
      job,
      stage: { ...stage, lastActivityAt: "2026-08-19T00:40:00.000Z" },
      agent: { state: "running", lastHeartbeatAt: "2026-08-19T00:59:30.000Z" },
      policy,
      nowMs,
    });
    assert.equal(inactive.state, "inactive");
    const offline = evaluateStageHealth({
      job,
      stage,
      agent: { state: "running", lastHeartbeatAt: "2026-08-19T00:40:00.000Z" },
      policy,
      nowMs,
    });
    assert.equal(offline.state, "offline");
    assert.equal(job.status, "running");

    const awaiting = evaluateStageHealth({
      job: { ...job, status: "waiting_approval" },
      stage: {
        ...stage,
        status: "waiting_approval",
        completedAt: "2026-08-19T00:10:00.000Z",
        lastActivityAt: "2026-08-19T00:10:00.000Z",
      },
      agent: { state: "idle", lastHeartbeatAt: "2026-08-19T00:10:00.000Z" },
      policy,
      nowMs,
    });
    assert.equal(awaiting.state, "awaiting_user");
    assert.equal(awaiting.shouldNotify, false);
    assert.equal(awaiting.elapsedSeconds, 600);
    assert.equal(awaiting.approvalWaitSeconds, 3000);
  });

  it("active monitor marks inactivity stalled and exhausts bounded recovery", async () => {
    const env = await monitoringJob("wi_plan_monitor_recovery");
    const started = await control(db, "/api/control/start-job", {
      jobId: env.jobId,
      payload: {
        instructionId: env.instructionId,
        environment: "production",
        isTest: false,
      },
    });
    assert.equal(started.statusCode, 200);
    const nowMs = Date.parse("2026-08-19T01:00:00.000Z");
    db.store.set(`${COL.MONITORING_CONFIG}/default`, {
      offlineAfterSeconds: 600,
      noActivityAfterSeconds: 300,
      defaultExpectedMaxSeconds: 120,
    });
    db.store.set(`${COL.AGENTS}/${env.agentId}`, {
      state: "running",
      lastHeartbeatAt: "2026-08-19T00:59:30.000Z",
    });
    db.store.set(`${COL.JOBS}/${env.jobId}`, {
      ...db.store.get(`${COL.JOBS}/${env.jobId}`),
      jobId: env.jobId,
      instructionId: env.instructionId,
      assignedAgentId: env.agentId,
      currentStage: "publish_prep",
      status: "running",
    });
    db.store.set(`${COL.JOBS}/${env.jobId}/stages/publish_prep`, {
      stageId: "publish_prep",
      stageNumber: 12,
      stageName: "등록 준비",
      status: "running",
      startedAt: "2026-08-19T00:00:00.000Z",
      lastActivityAt: "2026-08-19T00:40:00.000Z",
    });

    await evaluateActiveJobs(db, nowMs);
    let stage = db.store.get(`${COL.JOBS}/${env.jobId}/stages/publish_prep`);
    assert.equal(stage.status, "stalled");
    assert.equal(stage.recoveryAttempt, 1);
    assert.equal(stage.maxRecoveryAttempts, 3);
    assert.equal(stage.recoveryState, "requested");
    assert.equal(stage.retryable, true);
    assert.ok(stage.recoveryCommandId);
    assert.equal(
      db.store.get(`${COL.JOBS}/${env.jobId}/commands/${stage.recoveryCommandId}`).status,
      "queued"
    );

    // A still queued recovery is idempotent and does not burn the retry budget.
    await evaluateActiveJobs(db, nowMs + 500);
    stage = db.store.get(`${COL.JOBS}/${env.jobId}/stages/publish_prep`);
    assert.equal(stage.recoveryAttempt, 1);

    db.store.get(`${COL.JOBS}/${env.jobId}/commands/${stage.recoveryCommandId}`).status =
      "completed";
    await evaluateActiveJobs(db, nowMs + 1000);
    stage = db.store.get(`${COL.JOBS}/${env.jobId}/stages/publish_prep`);
    db.store.get(`${COL.JOBS}/${env.jobId}/commands/${stage.recoveryCommandId}`).status =
      "completed";
    await evaluateActiveJobs(db, nowMs + 2000);
    stage = db.store.get(`${COL.JOBS}/${env.jobId}/stages/publish_prep`);
    assert.equal(stage.status, "stage_transition_failed");
    assert.equal(stage.recoveryAttempt, 3);
    assert.equal(stage.recoveryState, "exhausted");
    assert.equal(stage.retryable, false);
    assert.equal(
      db.store.get(`${COL.PROJECTS}/${env.instructionId}/stages/publish_prep`).status,
      "stage_transition_failed"
    );
  });

  it("notification key separates revisions and deduplicates identical events", async () => {
    const common = {
      ownerUid: "user_a", instructionId: "wi_plan_keys", jobId: "job_x",
      stageId: "idea_clarify", stageNumber: 1, stageName: "아이디어 정리",
      eventType: "approval_required",
    };
    const a = await enqueueNotification(db, { ...common, revision: 1 });
    const duplicate = await enqueueNotification(db, { ...common, revision: 1 });
    const r2 = await enqueueNotification(db, { ...common, revision: 2 });
    assert.equal(a.created, true);
    assert.equal(duplicate.created, false);
    assert.equal(r2.created, true);
    assert.notEqual(a.id, r2.id);
  });

  it("safe cancel is authorized, idempotent, and preserves approvalMode + Agent", async () => {
    const iid = "wi_plan_cancel_safe";
    const jobId = "job_cancel_safe";
    const agentId = "agent_9830758291f9c64e";
    db.store.set(`${COL.AGENTS}/${agentId}`, {
      agentId, ownerUid: "user_a", state: "idle", currentJobId: "",
      enabled: true,
    });
    db.store.set(`${COL.JOBS}/${jobId}`, {
      jobId, ownerUid: "user_a", instructionId: iid,
      assignedAgentId: agentId, status: "waiting_approval", approvalMode: "manual",
      currentStage: "idea_clarify",
    });
    db.store.set(`${COL.PROJECTS}/${iid}`, {
      projectId: iid, ownerUid: "user_a", currentStageId: "idea_clarify",
      status: "awaiting_approval", approvalMode: "manual",
    });

    const first = await control(db, "/api/control/cancel-job", {
      jobId, instructionId: iid, projectId: iid,
    });
    assert.equal(first.statusCode, 200);
    assert.equal(first.body.state, "cancel_requested");
    assert.equal(db.store.get(`${COL.JOBS}/${jobId}`).approvalMode, "manual");
    assert.equal(db.store.get(`${COL.AGENTS}/${agentId}`).enabled, true);

    const duplicate = await control(db, "/api/control/cancel-job", {
      jobId, instructionId: iid, projectId: iid,
    });
    assert.equal(duplicate.statusCode, 200);
    assert.equal(duplicate.body.idempotent, true);
    assert.equal(duplicate.body.requestId, first.body.requestId);

    const forbidden = await control(db, "/api/control/cancel-job", {
      jobId, instructionId: iid, projectId: iid,
    }, "user_b");
    assert.equal(forbidden.statusCode, 403);
    const mismatch = await control(db, "/api/control/cancel-job", {
      jobId, instructionId: iid, projectId: "wi_plan_other",
    });
    assert.equal(mismatch.statusCode, 409);
  });

  it("cancel finalizer removes only the selected Run and clears stale pointer", async () => {
    const iid = "wi_plan_cancel_finalize";
    const other = "wi_plan_other_kept";
    const jobId = "job_cancel_finalize";
    const agentId = "agent_9830758291f9c64e";
    const opId = cancelOperationId("user_a", jobId, iid);
    db.store.set(`cancelOperations/${opId}`, {
      operationId: opId, ownerUid: "user_a", jobId, instructionId: iid,
      projectId: iid, agentId, status: "requested",
    });
    db.store.set(`${COL.AGENTS}/${agentId}`, {
      agentId, ownerUid: "user_a", state: "waiting_approval",
      currentJobId: jobId, currentStage: "idea_clarify", enabled: true,
    });
    db.store.set(`${COL.JOBS}/${jobId}`, {
      jobId, ownerUid: "user_a", instructionId: iid, assignedAgentId: agentId,
    });
    db.store.set(`${COL.JOBS}/${jobId}/commands/cmd_1`, { commandId: "cmd_1" });
    db.store.set(`${COL.JOBS}/${jobId}/stages/idea_clarify`, { stageId: "idea_clarify" });
    db.store.set(`${COL.PROJECTS}/${iid}`, { projectId: iid, ownerUid: "user_a" });
    db.store.set(`${COL.PROJECTS}/${iid}/requests/cancel_1`, { requestType: "cancel" });
    db.store.set(`${COL.PROJECTS}/${iid}/stages/idea_clarify`, { stageId: "idea_clarify" });
    db.store.set(`workInstructions/user_a__ebook__${iid}`, {
      ownerUid: "user_a", instructionId: iid,
    });
    db.store.set(`businessPlans/user_a__plan_cancel`, {
      ownerUid: "user_a", instructionId: iid,
    });
    db.store.set(`${COL.JOBS}/job_other`, {
      jobId: "job_other", ownerUid: "user_a", instructionId: other,
    });
    db.store.set(`${COL.PROJECTS}/${other}`, {
      projectId: other, ownerUid: "user_a",
    });
    const prefixes = [];
    const result = await finalizeCancelledRun(db, {
      uid: "user_a", operationId: opId, jobId, instructionId: iid,
      projectId: iid, agentId,
    }, {
      deleteArtifacts: async (prefix) => { prefixes.push(prefix); return 1; },
    });
    assert.equal(result.state, "completed");
    assert.equal(db.store.has(`${COL.JOBS}/${jobId}`), false);
    assert.equal(db.store.has(`${COL.PROJECTS}/${iid}`), false);
    assert.equal(db.store.has(`${COL.JOBS}/job_other`), true);
    assert.equal(db.store.has(`${COL.PROJECTS}/${other}`), true);
    assert.equal(db.store.get(`${COL.AGENTS}/${agentId}`).currentJobId, "");
    assert.equal(db.store.get(`${COL.AGENTS}/${agentId}`).state, "idle");
    assert.equal(db.store.get(`${COL.AGENTS}/${agentId}`).enabled, true);
    assert.deepEqual(prefixes, [
      `sotong24/artifacts/prod/${iid}/`,
      `sotong24/artifacts/test/${iid}/`,
    ]);
    const again = await finalizeCancelledRun(db, {
      uid: "user_a", operationId: opId, jobId, instructionId: iid,
      projectId: iid, agentId,
    });
    assert.equal(again.idempotent, true);
  });
});
