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
    async runTransaction(callback) {
      const tx = {
        get: (ref) => ref.get(),
        set: (ref, data, opts) => ref.set(data, opts),
      };
      return callback(tx);
    },
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

async function call(body, { auth = true, db, headers = {}, extras = {} } = {}) {
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
    ...extras,
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

  it("pickStageAllowlist accepts not_applicable", () => {
    const s = pickStageAllowlist(
      {
        stageId: "build_test",
        stageNumber: 8,
        status: "not_applicable",
      },
      { productType: "ebook", serverNowIso }
    );
    assert.equal(s.status, "not_applicable");
    assert.equal(s.stageId, "build_test");
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
        criteriaMet: true,
        workReport: "SHOULD_NOT_PERSIST",
        fullManuscript: "SECRET",
      },
      { productType: "ebook", serverNowIso }
    );
    assert.equal(s.stageId, "launch");
    assert.ok(!("workReport" in s));
    assert.ok(!("fullManuscript" in s));
  });

  it("allows https storage resultUrl/previewUrl", () => {
    const s = pickStageAllowlist(
      {
        stageId: "draft",
        stageNumber: 7,
        status: "awaiting_approval",
        approvalRequired: true,
        criteriaMet: true,
        resultUrl:
          "https://storage.googleapis.com/sotongware-control.appspot.com/sotong24/artifacts/test/x/draft/r1/a.md",
        previewUrl:
          "https://firebasestorage.googleapis.com/v0/b/sotongware-control.appspot.com/o/x",
      },
      { productType: "ebook", serverNowIso }
    );
    assert.ok(s.resultUrl.startsWith("https://storage.googleapis.com/"));
    assert.ok(s.previewUrl.startsWith("https://firebasestorage.googleapis.com/"));
  });

  it("rejects javascript/file/local resultUrl", () => {
    assert.throws(
      () =>
        pickStageAllowlist(
          {
            stageId: "draft",
            stageNumber: 7,
            resultUrl: "javascript:alert(1)",
          },
          { productType: "ebook", serverNowIso }
        ),
      /forbidden_scheme/
    );
    assert.throws(
      () =>
        pickStageAllowlist(
          {
            stageId: "draft",
            stageNumber: 7,
            resultUrl: "file:///C:/temp/a.md",
          },
          { productType: "ebook", serverNowIso }
        ),
      /forbidden_scheme/
    );
    assert.throws(
      () =>
        pickStageAllowlist(
          {
            stageId: "draft",
            stageNumber: 7,
            resultUrl: "C:\\Users\\me\\a.md",
          },
          { productType: "ebook", serverNowIso }
        ),
      /local_path_forbidden|backslash/
    );
    assert.throws(
      () =>
        pickStageAllowlist(
          {
            stageId: "draft",
            stageNumber: 7,
            resultUrl: "https://evil.example/a.md",
          },
          { productType: "ebook", serverNowIso }
        ),
      /storage_host_required/
    );
  });

  it("passes legacy stage payload without timing fields", () => {
    const s = pickStageAllowlist(
      {
        stageId: "idea_clarify",
        stageNumber: 1,
        stageName: "아이디어 정리",
        status: "in_progress",
        summary: "진행",
        resultUrl:
          "https://storage.googleapis.com/sotongware-control.appspot.com/sotong24/artifacts/test/x/draft/r1/a.md",
      },
      { productType: "ebook", serverNowIso: "2026-08-18T00:00:00.000Z" }
    );
    assert.equal(s.stageId, "idea_clarify");
    assert.ok(!("startedAt" in s));
    assert.ok(!("workDurationMs" in s));
    assert.ok(s.resultUrl.startsWith("https://storage.googleapis.com/"));
  });

  it("allows optional stage timing fields", () => {
    const s = pickStageAllowlist(
      {
        stageId: "idea_clarify",
        stageNumber: 1,
        status: "awaiting_approval",
        approvalRequired: true,
        criteriaMet: true,
        startedAt: "2026-08-18T00:00:00.000Z",
        completedAt: "2026-08-18T00:07:20.000Z",
        workDurationMs: 440000,
        revision: 2,
      },
      { productType: "ebook", serverNowIso: "2026-08-18T00:08:00.000Z" }
    );
    assert.equal(s.startedAt, "2026-08-18T00:00:00.000Z");
    assert.equal(s.completedAt, "2026-08-18T00:07:20.000Z");
    assert.equal(s.workDurationMs, 440000);
    assert.equal(s.revision, 2);
  });

  it("rejects approval-ready status without the completion contract", () => {
    assert.throws(
      () => pickStageAllowlist(
        {
          stageId: "problem_validate",
          stageNumber: 2,
          status: "awaiting_approval",
          approvalRequired: true,
          criteriaMet: false,
        },
        { productType: "ebook", serverNowIso }
      ),
      /completed_stage_requires_criteriaMet_true/
    );
    assert.throws(
      () => pickStageAllowlist(
        {
          stageId: "problem_validate",
          stageNumber: 2,
          status: "awaiting_approval",
          approvalRequired: false,
          criteriaMet: true,
        },
        { productType: "ebook", serverNowIso }
      ),
      /awaiting_approval_requires_approvalRequired_true/
    );
  });

  it("allows startedAt only", () => {
    const s = pickStageAllowlist(
      {
        stageId: "idea_clarify",
        stageNumber: 1,
        status: "in_progress",
        startedAt: "2026-08-18T00:00:00.000Z",
      },
      { productType: "ebook", serverNowIso: "2026-08-18T00:01:00.000Z" }
    );
    assert.equal(s.startedAt, "2026-08-18T00:00:00.000Z");
    assert.ok(!("completedAt" in s));
  });

  it("rejects negative workDurationMs", () => {
    assert.throws(
      () =>
        pickStageAllowlist(
          {
            stageId: "idea_clarify",
            stageNumber: 1,
            status: "in_progress",
            workDurationMs: -1,
          },
          { productType: "ebook", serverNowIso: "2026-08-18T00:00:00.000Z" }
        ),
      /out_of_range/
    );
  });

  it("rejects string workDurationMs", () => {
    assert.throws(
      () =>
        pickStageAllowlist(
          {
            stageId: "idea_clarify",
            stageNumber: 1,
            status: "in_progress",
            workDurationMs: "440000",
          },
          { productType: "ebook", serverNowIso: "2026-08-18T00:00:00.000Z" }
        ),
      /must_be_int/
    );
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
      criteriaMet: true,
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

  it("cancel tombstone rejects late heartbeat and project mirror recreation", async () => {
    const db = createMockDb();
    db.store.set("cancelOperations/cancel_late_mirror", {
      projectId: sampleProject.projectId,
      status: "completed",
    });

    const heartbeat = await call(
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
    const mirror = await call(
      { operation: "project_sync", project: sampleProject },
      { db }
    );

    assert.equal(heartbeat.statusCode, 409);
    assert.equal(heartbeat.body.code, "run_cancelled");
    assert.equal(mirror.statusCode, 409);
    assert.equal(mirror.body.code, "run_cancelled");
    assert.equal(
      db.store.has(`sotong24work_projects/${sampleProject.projectId}`),
      false
    );
  });

  it("same revision sync cannot reopen a terminal approval, r2 can become pending", async () => {
    const db = createMockDb();
    const path = `sotong24work_projects/${sampleProject.projectId}/stages/launch`;
    db.store.set(path, {
      stageId: "launch",
      stageNumber: 15,
      status: "awaiting_approval",
      criteriaMet: true,
      approvalRequired: true,
      approvalStatus: "approved",
      activeRequestId: "req_launch_r1",
      revision: 1,
    });
    const base = {
      stageId: "launch",
      stageNumber: 15,
      status: "awaiting_approval",
      criteriaMet: true,
      approvalRequired: true,
      approvalStatus: "pending",
    };
    const same = await call({
      operation: "stage_sync",
      project: sampleProject,
      stage: { ...base, revision: 1, activeRequestId: "req_reopened" },
    }, { db });
    assert.equal(same.statusCode, 200);
    assert.equal(db.store.get(path).approvalStatus, "approved");
    assert.equal(db.store.get(path).activeRequestId, "req_launch_r1");

    const r2 = await call({
      operation: "stage_sync",
      project: sampleProject,
      stage: { ...base, revision: 2, activeRequestId: "req_launch_r2" },
    }, { db });
    assert.equal(r2.statusCode, 200);
    assert.equal(db.store.get(path).approvalStatus, "pending");
    // activeRequestId is phone-owned and not part of the Agent allowlist. The
    // r2 submit guard allocates a new id because the stored r1 request differs.
    assert.equal(db.store.get(path).activeRequestId, "req_launch_r1");
    assert.equal(db.store.get(path).revision, 2);
  });

  it("same revision stale full_sync cannot regress awaiting approval or its project rollup", async () => {
    const db = createMockDb();
    const projectPath = `sotong24work_projects/${sampleProject.projectId}`;
    const stagePath = `${projectPath}/stages/launch`;
    db.store.set(projectPath, {
      ...sampleProject,
      status: "awaiting_approval",
      approvalStatus: "pending",
    });
    db.store.set(stagePath, {
      stageId: "launch",
      stageNumber: 15,
      status: "awaiting_approval",
      criteriaMet: true,
      approvalRequired: true,
      approvalStatus: "pending",
      revision: 1,
      lastActivityAt: "2026-08-19T02:39:16.313Z",
      activityState: "approval_preparing",
    });

    const staleStages = EBOOK_STAGE_IDS.map((id, index) => ({
      stageId: id,
      stageNumber: index + 1,
      status: index + 1 < 15 ? "completed" : index + 1 === 15 ? "in_progress" : "ready",
      criteriaMet: index + 1 < 15,
      approvalRequired: false,
      approvalStatus: "not_required",
      revision: 1,
    }));
    const res = await call({
      operation: "full_sync",
      project: { ...sampleProject, status: "in_progress", approvalStatus: "not_required" },
      stages: staleStages,
    }, { db });

    assert.equal(res.statusCode, 200);
    const stage = db.store.get(stagePath);
    const project = db.store.get(projectPath);
    assert.equal(stage.status, "awaiting_approval");
    assert.equal(stage.criteriaMet, true);
    assert.equal(stage.approvalRequired, true);
    assert.equal(stage.lastActivityAt, "2026-08-19T02:39:16.313Z");
    assert.equal(stage.activityState, "approval_preparing");
    assert.equal(project.status, "awaiting_approval");
    assert.equal(project.approvalStatus, "pending");
  });

  it("stage_sync persists resultUrl/previewUrl", async () => {
    const db = createMockDb();
    const resultUrl =
      "https://storage.googleapis.com/sotongware-control.appspot.com/sotong24/artifacts/test/wi_test_remote_e2e_1/draft/r1/a.md";
    const res = await call(
      {
        operation: "stage_sync",
        project: sampleProject,
        stage: {
          stageId: "draft",
          stageNumber: 7,
          status: "awaiting_approval",
          approvalRequired: true,
          criteriaMet: true,
          resultUrl,
          previewUrl: resultUrl,
          workReport: "NOPE",
        },
      },
      { db }
    );
    assert.equal(res.statusCode, 200);
    const sdoc = db.store.get(
      `sotong24work_projects/${sampleProject.projectId}/stages/draft`
    );
    assert.equal(sdoc.resultUrl, resultUrl);
    assert.equal(sdoc.previewUrl, resultUrl);
    assert.ok(!("workReport" in sdoc));
  });

  it("full_sync accepts all 18 canonical stages", async () => {
    const db = createMockDb();
    const stages = EBOOK_STAGE_IDS.map((id, i) => ({
      stageId: id,
      stageNumber: i + 1,
      status: i + 1 < 15 ? "completed" : i + 1 === 15 ? "awaiting_approval" : "ready",
      criteriaMet: i + 1 <= 15,
      approvalRequired: i + 1 === 15,
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

  it("full_sync accepts not_applicable stages and stores the status", async () => {
    const db = createMockDb();
    const stages = EBOOK_STAGE_IDS.map((id, i) => ({
      stageId: id,
      stageNumber: i + 1,
      status:
        id === "build_test" || id === "deploy"
          ? "not_applicable"
          : i + 1 < 15
            ? "completed"
            : i + 1 === 15
              ? "in_progress"
              : "ready",
      criteriaMet: i + 1 < 15 && id !== "build_test" && id !== "deploy",
    }));
    const res = await call(
      {
        operation: "full_sync",
        project: { ...sampleProject, status: "in_progress" },
        stages,
      },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    const build = db.store.get(
      `sotong24work_projects/${sampleProject.projectId}/stages/build_test`
    );
    const deploy = db.store.get(
      `sotong24work_projects/${sampleProject.projectId}/stages/deploy`
    );
    assert.equal(build.status, "not_applicable");
    assert.equal(deploy.status, "not_applicable");
  });

  it("stage_sync accepts not_applicable and persists it", async () => {
    const db = createMockDb();
    const res = await call(
      {
        operation: "stage_sync",
        project: { ...sampleProject, status: "in_progress" },
        stage: {
          stageId: "build_test",
          stageNumber: 8,
          status: "not_applicable",
          approvalRequired: false,
          approvalStatus: "not_required",
        },
      },
      { db }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    const sdoc = db.store.get(
      `sotong24work_projects/${sampleProject.projectId}/stages/build_test`
    );
    assert.equal(sdoc.status, "not_applicable");
    assert.equal(sdoc.stageId, "build_test");
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

  it("request_applied stores one idempotent workflow receipt", async () => {
    const db = createMockDb();
    seedProject(db, projectId, { currentStageId: "launch" });
    seedRequest(db, projectId, "req_apply_once", {
      requestId: "req_apply_once",
      projectId,
      stageId: "launch",
      requestType: "approve",
      status: "approved",
      createdAt: "2026-08-11T06:00:00.000Z",
      updatedAt: "2026-08-11T06:00:00.000Z",
    });
    const body = {
      operation: "request_applied",
      projectId,
      requestId: "req_apply_once",
      completedStageId: "launch",
      nextStageIdPrepared: "measure",
    };
    const first = await call(body, { db });
    const second = await call(body, { db });
    assert.equal(first.statusCode, 200);
    assert.equal(first.body.idempotent, false);
    assert.equal(second.statusCode, 200);
    assert.equal(second.body.idempotent, true);
    const saved = db.store.get(
      `sotong24work_projects/${projectId}/requests/req_apply_once`
    );
    assert.equal(saved.processed, true);
    assert.equal(saved.workflowApplied, true);
    assert.equal(saved.completedStageId, "launch");
    assert.equal(saved.nextStageIdPrepared, "measure");

    const conflict = await call({ ...body, nextStageIdPrepared: "learn" }, { db });
    assert.equal(conflict.statusCode, 409);
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
