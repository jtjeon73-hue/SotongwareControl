"use strict";

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { handleRelayRequest, rateLimiter } = require("../sotong24/relay");
const { EBOOK_STAGE_IDS, EBOOK_STAGE_BY_ID } = require("../sotong24/canonical");
const { pickProjectAllowlist, pickStageAllowlist } = require("../sotong24/validate");

const SECRET = "test-relay-secret-do-not-use-in-prod";

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

function mockReq({ body, headers = {}, method = "POST" }) {
  const h = {};
  for (const [k, v] of Object.entries(headers)) {
    h[k.toLowerCase()] = v;
  }
  return {
    method,
    body,
    rawBody: Buffer.from(JSON.stringify(body || {})),
    ip: "127.0.0.1",
    get(name) {
      return h[String(name).toLowerCase()] || "";
    },
  };
}

function createMockDb() {
  const store = new Map();
  function key(path) {
    return path.join("/");
  }
  function docRef(parts) {
    const path = parts.slice();
    return {
      async get() {
        const k = key(path);
        return {
          exists: store.has(k),
          data: () => store.get(k),
        };
      },
      async set(data, opts) {
        const k = key(path);
        if (opts && opts.merge && store.has(k)) {
          store.set(k, { ...store.get(k), ...data });
        } else {
          store.set(k, { ...data });
        }
      },
      collection(name) {
        return {
          doc(id) {
            return docRef([...path, name, id]);
          },
        };
      },
    };
  }
  return {
    store,
    collection(name) {
      return {
        doc(id) {
          return docRef([name, id]);
        },
      };
    },
  };
}

async function call(body, { auth = true, db, headers = {} } = {}) {
  const res = mockRes();
  const req = mockReq({
    body,
    headers: {
      ...(auth ? { Authorization: `Bearer ${SECRET}` } : {}),
      ...headers,
    },
  });
  await handleRelayRequest(req, res, {
    getSecret: () => SECRET,
    db: db || createMockDb(),
  });
  return res;
}

const sampleProject = {
  projectId: "wi_plan_1785905165067",
  title: "테스트 전자책",
  productType: "ebook",
  currentStage: "launch",
  totalStages: 18,
  progress: 75,
  status: "awaiting_approval",
  approvalStatus: "pending",
  pcStatus: "online",
  stageNumber: 15,
};

describe("canonical ebook stages", () => {
  it("has 18 ids including launch at 15", () => {
    assert.equal(EBOOK_STAGE_IDS.length, 18);
    assert.equal(EBOOK_STAGE_BY_ID.get("launch").order, 15);
  });
});

describe("allowlist / validation", () => {
  const serverNowIso = "2026-08-11T03:00:00.000Z";

  it("accepts MFC dry-run project shape", () => {
    const p = pickProjectAllowlist(sampleProject, { serverNowIso });
    assert.equal(p.projectId, sampleProject.projectId);
    assert.equal(p.currentStage, 15);
    assert.equal(p.currentStageId, "launch");
    assert.equal(p.progress, 75);
    assert.equal(p.isDemo, false);
    assert.equal(p.lastHeartbeat, serverNowIso);
    assert.ok(!("workReport" in p));
  });

  it("rejects path injection projectId", () => {
    assert.throws(
      () =>
        pickProjectAllowlist(
          { ...sampleProject, projectId: "../etc" },
          { serverNowIso }
        ),
      /path_injection|invalid_format/
    );
  });

  it("rejects progress out of range", () => {
    assert.throws(
      () =>
        pickProjectAllowlist({ ...sampleProject, progress: 101 }, { serverNowIso }),
      /out_of_range/
    );
    assert.throws(
      () =>
        pickProjectAllowlist({ ...sampleProject, progress: -1 }, { serverNowIso }),
      /out_of_range/
    );
  });

  it("rejects unknown ebook stageId", () => {
    assert.throws(
      () =>
        pickStageAllowlist(
          {
            stageId: "not_a_real_stage",
            stageNumber: 1,
            status: "ready",
          },
          { productType: "ebook", serverNowIso }
        ),
      /unknown_ebook_stageId/
    );
  });

  it("rejects stageNumber mismatch", () => {
    assert.throws(
      () =>
        pickStageAllowlist(
          { stageId: "launch", stageNumber: 1, status: "ready" },
          { productType: "ebook", serverNowIso }
        ),
      /stageNumber_mismatch/
    );
  });

  it("ignores unexpected fields on stage", () => {
    const s = pickStageAllowlist(
      {
        stageId: "launch",
        stageNumber: 15,
        stageName: "공개 및 공유",
        status: "awaiting_approval",
        approvalStatus: "pending",
        summary: "미리보기",
        resultPreview: "ok",
        approvalRequired: true,
        workReport: "SHOULD_NOT_PERSIST",
        fullManuscript: "SECRET",
      },
      { productType: "ebook", serverNowIso }
    );
    assert.equal(s.stageId, "launch");
    assert.ok(!("workReport" in s));
    assert.ok(!("fullManuscript" in s));
  });
});

describe("relay HTTP handler", () => {
  beforeEach(() => {
    rateLimiter.reset();
  });

  it("rejects missing auth", async () => {
    const res = await call(
      { operation: "heartbeat", project: { projectId: "p1", productType: "ebook" } },
      { auth: false }
    );
    assert.equal(res.statusCode, 401);
    assert.equal(res.body.ok, false);
  });

  it("rejects wrong auth", async () => {
    const db = createMockDb();
    const res = mockRes();
    const req = mockReq({
      body: {
        operation: "heartbeat",
        project: { projectId: "p1", productType: "ebook" },
      },
      headers: { Authorization: "Bearer wrong-token" },
    });
    await handleRelayRequest(req, res, { getSecret: () => SECRET, db });
    assert.equal(res.statusCode, 403);
  });

  it("rejects empty secret configuration", async () => {
    const res = mockRes();
    const req = mockReq({
      body: {
        operation: "heartbeat",
        project: { projectId: "p1", productType: "ebook" },
      },
      headers: { Authorization: `Bearer ${SECRET}` },
    });
    await handleRelayRequest(req, res, {
      getSecret: () => "",
      db: createMockDb(),
    });
    assert.equal(res.statusCode, 503);
  });

  it("heartbeat upserts lastHeartbeat", async () => {
    const db = createMockDb();
    const res = await call(
      {
        operation: "heartbeat",
        project: {
          projectId: sampleProject.projectId,
          productType: "ebook",
          pcStatus: "online",
        },
      },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    const doc = db.store.get(`sotong24work_projects/${sampleProject.projectId}`);
    assert.ok(doc.lastHeartbeat);
    assert.equal(doc.pcStatus, "online");
    assert.equal(doc.isDemo, false);
  });

  it("project_sync writes allowlisted fields", async () => {
    const db = createMockDb();
    const res = await call(
      { operation: "project_sync", project: sampleProject },
      { db }
    );
    assert.equal(res.statusCode, 200);
    const doc = db.store.get(`sotong24work_projects/${sampleProject.projectId}`);
    assert.equal(doc.currentStage, 15);
    assert.equal(doc.progress, 75);
    assert.equal(doc.status, "awaiting_approval");
    assert.equal(doc.approvalStatus, "pending");
    assert.equal(doc.currentStageId, "launch");
  });

  it("stage_sync upserts stage and is idempotent", async () => {
    const db = createMockDb();
    const stage = {
      stageId: "launch",
      stageNumber: 15,
      status: "awaiting_approval",
      approvalStatus: "pending",
      approvalRequired: true,
      summary: "출시 대기",
      resultPreview: "preview",
    };
    const body = {
      operation: "stage_sync",
      project: sampleProject,
      stage,
    };
    const r1 = await call(body, { db });
    const r2 = await call(body, { db });
    assert.equal(r1.statusCode, 200);
    assert.equal(r2.statusCode, 200);
    assert.equal(r2.body.stages[0].created, false);
    const sdoc = db.store.get(
      `sotong24work_projects/${sampleProject.projectId}/stages/launch`
    );
    assert.equal(sdoc.stageNumber, 15);
    assert.equal(sdoc.stageName, "공개 및 공유");
  });

  it("full_sync accepts all 18 canonical stages", async () => {
    const db = createMockDb();
    const stages = EBOOK_STAGE_IDS.map((id, i) => ({
      stageId: id,
      stageNumber: i + 1,
      status: i + 1 < 15 ? "completed" : i + 1 === 15 ? "awaiting_approval" : "ready",
      approvalStatus: i + 1 === 15 ? "pending" : "not_required",
    }));
    const res = await call(
      {
        operation: "full_sync",
        project: sampleProject,
        stages,
      },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.stages.length, 18);
  });

  it("duplicate project_sync does not destroy data", async () => {
    const db = createMockDb();
    await call({ operation: "project_sync", project: sampleProject }, { db });
    await call(
      {
        operation: "project_sync",
        project: { ...sampleProject, progress: 75 },
      },
      { db }
    );
    const doc = db.store.get(`sotong24work_projects/${sampleProject.projectId}`);
    assert.equal(doc.progress, 75);
    assert.equal(doc.projectId, sampleProject.projectId);
  });

  it("rejects invalid status", async () => {
    const res = await call({
      operation: "project_sync",
      project: { ...sampleProject, status: "hacking" },
    });
    assert.equal(res.statusCode, 400);
  });
});
