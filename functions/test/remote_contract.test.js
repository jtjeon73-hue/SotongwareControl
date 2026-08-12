"use strict";

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { handleApiRequest } = require("../remote/router");
const { createMemoryDb } = require("../remote/memory_db");
const { sha256Hex } = require("../remote/crypto_util");
const { COL, PROTOCOL_VERSION } = require("../remote/constants");

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
        protocolVersion: "1.0",
      },
      { token: agentToken }
    );
    assert.equal(r2.statusCode, 200);
    assert.ok(db.store.get(`${COL.JOBS}/${jobId}/stages/launch`));
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
});
