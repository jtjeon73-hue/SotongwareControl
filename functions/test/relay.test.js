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
  const writes = [];

  function key(path) {
    return path.join("/");
  }

  function listChildren(parentParts, collectionName) {
    const prefix = [...parentParts, collectionName].join("/") + "/";
    const docs = [];
    for (const [k, v] of store.entries()) {
      if (!k.startsWith(prefix)) continue;
      const rest = k.slice(prefix.length);
      if (!rest || rest.includes("/")) continue; // only direct children
      docs.push({
        id: rest,
        data: () => ({ ...v }),
      });
    }
    return docs;
  }

  function collectionRef(parentParts, name) {
    const parts = [...parentParts, name];
    return {
      doc(id) {
        return docRef([...parts, id]);
      },
      orderBy() {
        return {
          limit(n) {
            return {
              async get() {
                const docs = listChildren(parentParts, name).slice(0, n);
                return { docs };
              },
            };
          },
        };
      },
      limit(n) {
        return {
          async get() {
            const docs = listChildren(parentParts, name).slice(0, n);
            return { docs };
          },
        };
      },
      async get() {
        return { docs: listChildren(parentParts, name) };
      },
    };
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
        writes.push({ op: "set", path: k, data: { ...data }, opts });
        if (opts && opts.merge && store.has(k)) {
          store.set(k, { ...store.get(k), ...data });
        } else {
          store.set(k, { ...data });
        }
      },
      async update(data) {
        const k = key(path);
        writes.push({ op: "update", path: k, data: { ...data } });
        store.set(k, { ...(store.get(k) || {}), ...data });
      },
      async delete() {
        const k = key(path);
        writes.push({ op: "delete", path: k });
        store.delete(k);
      },
      collection(name) {
        return collectionRef(path, name);
      },
    };
  }

  return {
    store,
    writes,
    collection(name) {
      return collectionRef([], name);
    },
  };
}

function seedProject(db, projectId, data = {}) {
  db.store.set(`sotong24work_projects/${projectId}`, {
    projectId,
    productType: "ebook",
    currentStage: 15,
    currentStageId: "launch",
    isDemo: false,
    ...data,
  });
}

function seedRequest(db, projectId, requestId, data) {
  db.store.set(
    `sotong24work_projects/${projectId}/requests/${requestId}`,
    data
  );
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

describe("request_poll", () => {
  const projectId = sampleProject.projectId;

  beforeEach(() => {
    rateLimiter.reset();
  });

  it("valid auth + no requests → 200 []", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    const res = await call(
      {
        operation: "request_poll",
        projectId,
        currentStageId: "launch",
      },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.operation, "request_poll");
    assert.deepEqual(res.body.requests, []);
  });

  it("returns valid approval request", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    seedRequest(db, projectId, "req_approve_1", {
      requestId: "req_approve_1",
      projectId,
      stageId: "launch",
      requestType: "approve",
      status: "approved",
      message: "",
      createdAt: "2026-08-11T05:00:00.000Z",
      updatedAt: "2026-08-11T05:00:00.000Z",
      processedAt: "2026-08-11T05:00:00.000Z",
    });
    const res = await call(
      { operation: "request_poll", projectId, currentStageId: "launch" },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.requests.length, 1);
    assert.equal(res.body.requests[0].requestType, "approve");
    assert.equal(res.body.requests[0].status, "approved");
    assert.ok(!("workReport" in res.body.requests[0]));
  });

  it("returns valid revision request", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    seedRequest(db, projectId, "req_rev_1", {
      requestId: "req_rev_1",
      projectId,
      stageId: "launch",
      requestType: "revision_request",
      status: "revision_requested",
      message: "표지 문구 수정",
      createdAt: "2026-08-11T05:01:00.000Z",
      updatedAt: "2026-08-11T05:01:00.000Z",
      processedAt: "2026-08-11T05:01:00.000Z",
    });
    const res = await call(
      { operation: "request_poll", projectId, currentStageId: "launch" },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.requests[0].requestType, "revision_request");
    assert.equal(res.body.requests[0].message, "표지 문구 수정");
  });

  it("returns multiple requests newest first within limit", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    seedRequest(db, projectId, "req_old", {
      requestId: "req_old",
      projectId,
      stageId: "launch",
      requestType: "approve",
      status: "approved",
      message: "",
      createdAt: "2026-08-11T04:00:00.000Z",
      updatedAt: "2026-08-11T04:00:00.000Z",
      processedAt: "2026-08-11T04:00:00.000Z",
    });
    seedRequest(db, projectId, "req_new", {
      requestId: "req_new",
      projectId,
      stageId: "launch",
      requestType: "revision_request",
      status: "revision_requested",
      message: "new",
      createdAt: "2026-08-11T06:00:00.000Z",
      updatedAt: "2026-08-11T06:00:00.000Z",
      processedAt: "2026-08-11T06:00:00.000Z",
    });
    const res = await call(
      {
        operation: "request_poll",
        projectId,
        currentStageId: "launch",
        limit: 1,
      },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.requests.length, 1);
    assert.equal(res.body.requests[0].requestId, "req_new");
  });

  it("rejects path injection projectId", async () => {
    const res = await call({
      operation: "request_poll",
      projectId: "../test",
      currentStageId: "launch",
    });
    assert.equal(res.statusCode, 400);
    assert.match(String(res.body.message), /path_injection|invalid_format/);
  });

  it("rejects wrong currentStageId (unknown)", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    const res = await call(
      {
        operation: "request_poll",
        projectId,
        currentStageId: "not_a_stage",
      },
      { db }
    );
    assert.equal(res.statusCode, 400);
  });

  it("excludes old stage requests", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    seedRequest(db, projectId, "req_old_stage", {
      requestId: "req_old_stage",
      projectId,
      stageId: "deploy",
      requestType: "approve",
      status: "approved",
      message: "",
      createdAt: "2026-08-11T05:00:00.000Z",
      updatedAt: "2026-08-11T05:00:00.000Z",
      processedAt: "2026-08-11T05:00:00.000Z",
    });
    const res = await call(
      { operation: "request_poll", projectId, currentStageId: "launch" },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.requests, []);
  });

  it("excludes future stage requests", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    seedRequest(db, projectId, "req_future", {
      requestId: "req_future",
      projectId,
      stageId: "measure",
      requestType: "approve",
      status: "approved",
      message: "",
      createdAt: "2026-08-11T05:00:00.000Z",
      updatedAt: "2026-08-11T05:00:00.000Z",
      processedAt: "2026-08-11T05:00:00.000Z",
    });
    const res = await call(
      { operation: "request_poll", projectId, currentStageId: "launch" },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.requests.length, 0);
  });

  it("excludes malformed request safely", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    seedRequest(db, projectId, "req_bad", {
      projectId,
      stageId: "launch",
      // missing requestType/status
      message: "x",
    });
    const res = await call(
      { operation: "request_poll", projectId, currentStageId: "launch" },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.requests, []);
  });

  it("excludes oversized message", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    seedRequest(db, projectId, "req_huge", {
      requestId: "req_huge",
      projectId,
      stageId: "launch",
      requestType: "revision_request",
      status: "revision_requested",
      message: "x".repeat(2001),
      createdAt: "2026-08-11T05:00:00.000Z",
      updatedAt: "2026-08-11T05:00:00.000Z",
      processedAt: "2026-08-11T05:00:00.000Z",
    });
    const res = await call(
      { operation: "request_poll", projectId, currentStageId: "launch" },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.requests, []);
  });

  it("rejects unauthenticated", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    const res = await call(
      { operation: "request_poll", projectId, currentStageId: "launch" },
      { auth: false, db }
    );
    assert.equal(res.statusCode, 401);
  });

  it("rejects wrong token", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    const res = mockRes();
    const req = mockReq({
      body: {
        operation: "request_poll",
        projectId,
        currentStageId: "launch",
      },
      headers: { Authorization: "Bearer wrong" },
    });
    await handleRelayRequest(req, res, { getSecret: () => SECRET, db });
    assert.equal(res.statusCode, 403);
  });

  it("rejects unknown operation still", async () => {
    const res = await call({
      operation: "drop_all_tables",
      projectId,
      currentStageId: "launch",
    });
    assert.equal(res.statusCode, 400);
    assert.equal(res.body.message, "operation invalid");
  });

  it("returns 404 when project not found", async () => {
    const db = createMockDb();
    const res = await call(
      {
        operation: "request_poll",
        projectId: "wi_plan_missing_999",
        currentStageId: "launch",
      },
      { db }
    );
    assert.equal(res.statusCode, 404);
  });

  it("blocks isDemo project", async () => {
    const db = createMockDb();
    seedProject(db, projectId, { isDemo: true });
    const res = await call(
      { operation: "request_poll", projectId, currentStageId: "launch" },
      { db }
    );
    assert.equal(res.statusCode, 403);
    assert.equal(res.body.message, "demo_project_blocked");
  });

  it("does not write on request_poll", async () => {
    const db = createMockDb();
    seedProject(db, projectId, {
      approvalStatus: "pending",
      status: "awaiting_approval",
    });
    seedRequest(db, projectId, "req_a", {
      requestId: "req_a",
      projectId,
      stageId: "launch",
      requestType: "approve",
      status: "approved",
      message: "",
      createdAt: "2026-08-11T05:00:00.000Z",
      updatedAt: "2026-08-11T05:00:00.000Z",
      processedAt: "2026-08-11T05:00:00.000Z",
    });
    const before = JSON.stringify([...db.store.entries()]);
    const res = await call(
      { operation: "request_poll", projectId, currentStageId: "launch" },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(db.writes.length, 0);
    assert.equal(JSON.stringify([...db.store.entries()]), before);
    const reqDoc = db.store.get(
      `sotong24work_projects/${projectId}/requests/req_a`
    );
    assert.equal(reqDoc.processedAt, "2026-08-11T05:00:00.000Z");
  });

  it("rejects unexpected fields", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    const res = await call(
      {
        operation: "request_poll",
        projectId,
        currentStageId: "launch",
        firestorePath: "evil/path",
      },
      { db }
    );
    assert.equal(res.statusCode, 400);
    assert.match(String(res.body.message), /unexpected_field/);
  });

  it("rejects currentStageId mismatch with project", async () => {
    const db = createMockDb();
    seedProject(db, projectId, {
      currentStageId: "launch",
      currentStage: 15,
    });
    const res = await call(
      {
        operation: "request_poll",
        projectId,
        currentStageId: "deploy",
      },
      { db }
    );
    assert.equal(res.statusCode, 400);
    assert.match(String(res.body.message), /mismatch_project/);
  });

  it("rate limits excessive request_poll", async () => {
    const db = createMockDb();
    seedProject(db, projectId);
    let last = null;
    for (let i = 0; i < 31; i++) {
      last = await call(
        { operation: "request_poll", projectId, currentStageId: "launch" },
        { db }
      );
    }
    assert.equal(last.statusCode, 429);
  });
});
