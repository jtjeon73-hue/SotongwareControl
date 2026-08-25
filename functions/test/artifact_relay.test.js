"use strict";

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { handleRelayRequest, rateLimiter } = require("../sotong24/relay");
const {
  sanitizeHttpsUrl,
  sanitizeFileName,
  buildArtifactStoragePath,
  parseArtifactUploadInit,
  parseArtifactDownloadRequest,
  createAttachmentDownloadGrant,
  buildAttachmentDisposition,
  UPLOAD_URL_TTL_MS,
  DOWNLOAD_URL_TTL_MS,
  ARTIFACT_MAX_BYTES,
  maskSignedUrlForLog,
  mapArtifactStorageError,
} = require("../sotong24/artifact");

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
  function collectionRef(parentParts, name) {
    const parts = [...parentParts, name];
    return {
      doc(id) {
        return {
          async get() {
            const k = [...parts, id].join("/");
            return {
              exists: store.has(k),
              data: () => store.get(k),
            };
          },
          collection(n) {
            return collectionRef([...parts, id], n);
          },
        };
      },
    };
  }
  return {
    store,
    collection(name) {
      return collectionRef([], name);
    },
  };
}

function mockStorage({ exists = true, size = 312, contentType } = {}) {
  const signed = [];
  return {
    signed,
    async signUrl(opts) {
      signed.push(opts);
      const action = opts.action === "write" ? "upload" : "download";
      return `https://storage.googleapis.com/sotongware-control.appspot.com/${opts.path}?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Signature=SECRET_${action}&expires=${opts.expiresMs}`;
    },
    async getFileMetadata(path) {
      if (!exists) return { exists: false };
      return {
        exists: true,
        size,
        contentType: contentType || "text/markdown; charset=utf-8",
        path,
      };
    },
  };
}

async function call(body, { auth = true, db, storage } = {}) {
  const res = mockRes();
  const req = mockReq({
    body,
    headers: auth ? { Authorization: `Bearer ${SECRET}` } : {},
  });
  const store = storage || mockStorage();
  await handleRelayRequest(req, res, {
    getSecret: () => SECRET,
    db: db || createMockDb(),
    signUrl: store.signUrl.bind(store),
    getFileMetadata: store.getFileMetadata.bind(store),
  });
  return { res, store };
}

const baseInit = {
  operation: "artifact_upload_init",
  instructionId: "wi_test_remote_e2e_1786792704742",
  productType: "ebook",
  stageId: "draft",
  stageNumber: 7,
  revision: 2,
  fileName: "07_draft_e2e_result_r2.md",
  contentType: "text/markdown; charset=utf-8",
  sizeBytes: 312,
};

/** Real Codex AI explicit artifact (stageIndex was 0 → Agent sent stageNumber 0). */
const aiExplicitInit = {
  operation: "artifact_upload_init",
  instructionId: "wi_test_remote_e2e_codex_1786877899287",
  productType: "ebook",
  stageId: "idea_clarify",
  stageNumber: 0,
  revision: 1,
  fileName: "codex_ai_smoke.md",
  contentType: "text/markdown; charset=utf-8",
  sizeBytes: 150,
  // Agent also keeps these locally; Relay ignores extras.
  taskId: "wi_test_remote_e2e_codex_1786877899287__idea_clarify__r1",
  source: "ai_explicit",
};

describe("artifact URL sanitize", () => {
  it("allows https storage hosts", () => {
    const u = sanitizeHttpsUrl(
      "https://storage.googleapis.com/bucket/path/a.md",
      "resultUrl",
      { requireStorageHost: true }
    );
    assert.ok(u.startsWith("https://"));
  });

  it("rejects javascript/file/local/evil host", () => {
    assert.throws(
      () => sanitizeHttpsUrl("javascript:alert(1)", "resultUrl"),
      /forbidden_scheme/
    );
    assert.throws(
      () => sanitizeHttpsUrl("file:///tmp/a.md", "resultUrl"),
      /forbidden_scheme/
    );
    assert.throws(
      () => sanitizeHttpsUrl("C:\\Users\\a.md", "resultUrl"),
      /local_path|backslash/
    );
    assert.throws(
      () =>
        sanitizeHttpsUrl("https://evil.example/a.md", "resultUrl", {
          requireStorageHost: true,
        }),
      /storage_host_required/
    );
  });
});

describe("artifact path / filename", () => {
  it("builds deterministic path with revision separation", () => {
    const p1 = buildArtifactStoragePath({
      instructionId: "wi_test_remote_e2e_1",
      stageId: "draft",
      revision: 1,
      fileName: "07_draft.md",
    });
    const p2 = buildArtifactStoragePath({
      instructionId: "wi_test_remote_e2e_1",
      stageId: "draft",
      revision: 2,
      fileName: "07_draft.md",
    });
    assert.equal(
      p1,
      "sotong24/artifacts/test/wi_test_remote_e2e_1/draft/r1/07_draft.md"
    );
    assert.equal(
      p2,
      "sotong24/artifacts/test/wi_test_remote_e2e_1/draft/r2/07_draft.md"
    );
    assert.notEqual(p1, p2);
  });

  it("rejects path traversal filename", () => {
    assert.throws(() => sanitizeFileName("../secret.md"), /path_traversal/);
    assert.throws(() => sanitizeFileName("a/b.md"), /path_traversal/);
    assert.throws(() => sanitizeFileName("a\\b.md"), /path_traversal/);
  });

  it("rejects bad extensions", () => {
    assert.throws(() => sanitizeFileName("x.exe"), /extension_not_allowed/);
    assert.throws(() => sanitizeFileName("x.zip"), /extension_not_allowed/);
    assert.throws(
      () => sanitizeFileName("service-account.json"),
      /forbidden_pattern|extension/
    );
  });

  it("allows phone-openable PDF and raster image filenames", () => {
    assert.equal(sanitizeFileName("final_ebook.pdf"), "final_ebook.pdf");
    assert.equal(sanitizeFileName("cover.png"), "cover.png");
    assert.equal(sanitizeFileName("cover.jpg"), "cover.jpg");
    assert.equal(sanitizeFileName("cover.jpeg"), "cover.jpeg");
    assert.throws(() => sanitizeFileName("active.svg"), /extension_not_allowed/);
    assert.throws(() => sanitizeFileName("active.html"), /extension_not_allowed/);
  });
});

describe("artifact_upload_init", () => {
  beforeEach(() => {
    rateLimiter.reset();
  });

  it("requires auth", async () => {
    const { res } = await call(baseInit, { auth: false });
    assert.equal(res.statusCode, 401);
  });

  it("rejects wi_plan without explicit prod lane flags", async () => {
    const { res } = await call({
      ...baseInit,
      instructionId: "wi_plan_1785905165067",
    });
    assert.equal(res.statusCode, 403);
    assert.ok(
      ["invalid_test_instruction", "invalid_argument", "invalid_prod_instruction"].includes(
        res.body.code
      )
    );
  });

  it("rejects missing TEST prefix", async () => {
    const { res } = await call({
      ...baseInit,
      instructionId: "wi_other_123",
    });
    assert.equal(res.statusCode, 403);
  });

  it("PROD wi_plan + namespace=prod returns signed PUT under artifacts/prod", async () => {
    const prodInit = {
      operation: "artifact_upload_init",
      instructionId: "wi_plan_NEWID_PILOT",
      productType: "ebook",
      stageId: "idea_clarify",
      stageNumber: 1,
      revision: 1,
      fileName: "01_idea_clarify_result.md",
      contentType: "text/markdown; charset=utf-8",
      sizeBytes: 1234,
      source: "ai_explicit",
      isTest: false,
      namespace: "prod",
      taskId: "wi_plan_NEWID_PILOT__idea_clarify__r1",
      workerType: "codex",
      storagePath:
        "sotong24/artifacts/prod/wi_plan_NEWID_PILOT/idea_clarify/r1/01_idea_clarify_result.md",
    };
    const { res, store } = await call(prodInit);
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(
      res.body.storagePath,
      "sotong24/artifacts/prod/wi_plan_NEWID_PILOT/idea_clarify/r1/01_idea_clarify_result.md"
    );
    assert.equal(res.body.namespace, "prod");
    assert.equal(res.body.isTest, false);
    assert.equal(store.signed[0].action, "write");
    assert.ok(store.signed[0].path.startsWith("sotong24/artifacts/prod/"));
  });

  it("rejects test/prod cross namespace (test id + prod ns)", async () => {
    const { res } = await call({
      ...baseInit,
      isTest: false,
      namespace: "prod",
      source: "ai_explicit",
      workerType: "codex",
      taskId: "wi_test_remote_e2e_1786792704742__draft__r2",
    });
    assert.equal(res.statusCode, 403);
  });

  it("rejects prod id on test lane", async () => {
    const { res } = await call({
      ...baseInit,
      instructionId: "wi_plan_1785905165067",
      isTest: true,
      namespace: "test",
    });
    assert.equal(res.statusCode, 403);
  });

  it("PROD stageNumber 0 derives canonical order", async () => {
    const { res } = await call({
      operation: "artifact_upload_init",
      instructionId: "wi_plan_PILOT_STAGE0",
      productType: "ebook",
      stageId: "idea_clarify",
      stageNumber: 0,
      revision: 1,
      fileName: "01_idea_clarify_result.md",
      contentType: "text/markdown; charset=utf-8",
      sizeBytes: 100,
      source: "ai_explicit",
      isTest: false,
      namespace: "prod",
      taskId: "wi_plan_PILOT_STAGE0__idea_clarify__r1",
      workerType: "codex",
    });
    assert.equal(res.statusCode, 200);
    assert.ok(res.body.storagePath.includes("/idea_clarify/r1/"));
  });

  it("PROD final PDF returns a signed PUT with an exact content type", async () => {
    const { res, store } = await call({
      operation: "artifact_upload_init",
      instructionId: "wi_plan_PILOT_PDF",
      productType: "ebook",
      stageId: "publish_prep",
      stageNumber: 12,
      revision: 1,
      fileName: "final_ebook.pdf",
      contentType: "application/pdf",
      sizeBytes: 195077,
      source: "ai_explicit",
      isTest: false,
      namespace: "prod",
      taskId: "wi_plan_PILOT_PDF__publish_prep__r1",
      workerType: "codex",
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.requiredHeaders["Content-Type"], "application/pdf");
    assert.equal(store.signed[0].contentType, "application/pdf");
    assert.match(res.body.storagePath, /\/publish_prep\/r1\/final_ebook\.pdf$/);
  });

  it("rejects a PDF declared as plain text", async () => {
    const { res } = await call({
      ...baseInit,
      fileName: "final_ebook.pdf",
      contentType: "text/plain",
    });
    assert.equal(res.statusCode, 400);
    assert.match(String(res.body.message || ""), /contentType_mismatch_extension/);
  });

  it("PROD rejects stageNumber mismatch", async () => {
    const { res } = await call({
      operation: "artifact_upload_init",
      instructionId: "wi_plan_PILOT_MISMATCH",
      productType: "ebook",
      stageId: "idea_clarify",
      stageNumber: 7,
      revision: 1,
      fileName: "01_idea_clarify_result.md",
      contentType: "text/markdown; charset=utf-8",
      sizeBytes: 100,
      source: "ai_explicit",
      isTest: false,
      namespace: "prod",
      taskId: "wi_plan_PILOT_MISMATCH__idea_clarify__r1",
      workerType: "codex",
    });
    assert.equal(res.statusCode, 400);
    assert.match(String(res.body.message || ""), /stageNumber_mismatch/);
  });

  it("PROD rejects invalid revision", async () => {
    const { res } = await call({
      operation: "artifact_upload_init",
      instructionId: "wi_plan_PILOT_REV",
      productType: "ebook",
      stageId: "idea_clarify",
      stageNumber: 1,
      revision: 0,
      fileName: "01_idea_clarify_result.md",
      contentType: "text/markdown; charset=utf-8",
      sizeBytes: 100,
      source: "ai_explicit",
      isTest: false,
      namespace: "prod",
      taskId: "wi_plan_PILOT_REV__idea_clarify__r0",
      workerType: "codex",
    });
    assert.equal(res.statusCode, 400);
  });

  it("PROD rejects traversal filename", async () => {
    const { res } = await call({
      operation: "artifact_upload_init",
      instructionId: "wi_plan_PILOT_TRAV",
      productType: "ebook",
      stageId: "idea_clarify",
      stageNumber: 1,
      revision: 1,
      fileName: "../secret.md",
      contentType: "text/markdown; charset=utf-8",
      sizeBytes: 100,
      source: "ai_explicit",
      isTest: false,
      namespace: "prod",
      taskId: "wi_plan_PILOT_TRAV__idea_clarify__r1",
      workerType: "codex",
    });
    assert.equal(res.statusCode, 400);
  });

  it("PROD rejects unsupported contentType", async () => {
    const { res } = await call({
      operation: "artifact_upload_init",
      instructionId: "wi_plan_PILOT_CT",
      productType: "ebook",
      stageId: "idea_clarify",
      stageNumber: 1,
      revision: 1,
      fileName: "01_idea_clarify_result.md",
      contentType: "application/octet-stream",
      sizeBytes: 100,
      source: "ai_explicit",
      isTest: false,
      namespace: "prod",
      taskId: "wi_plan_PILOT_CT__idea_clarify__r1",
      workerType: "codex",
    });
    assert.equal(res.statusCode, 400);
  });

  it("PROD rejects oversized", async () => {
    const { res } = await call({
      operation: "artifact_upload_init",
      instructionId: "wi_plan_PILOT_BIG",
      productType: "ebook",
      stageId: "idea_clarify",
      stageNumber: 1,
      revision: 1,
      fileName: "01_idea_clarify_result.md",
      contentType: "text/markdown; charset=utf-8",
      sizeBytes: ARTIFACT_MAX_BYTES + 1,
      source: "ai_explicit",
      isTest: false,
      namespace: "prod",
      taskId: "wi_plan_PILOT_BIG__idea_clarify__r1",
      workerType: "codex",
    });
    assert.equal(res.statusCode, 413);
  });

  it("PROD complete returns signed GET", async () => {
    const storagePath =
      "sotong24/artifacts/prod/wi_plan_PILOT_DONE/idea_clarify/r1/01_idea_clarify_result.md";
    const { res, store } = await call(
      {
        operation: "artifact_upload_complete",
        instructionId: "wi_plan_PILOT_DONE",
        productType: "ebook",
        stageId: "idea_clarify",
        stageNumber: 1,
        revision: 1,
        fileName: "01_idea_clarify_result.md",
        contentType: "text/markdown; charset=utf-8",
        sizeBytes: 1234,
        storagePath,
      },
      { storage: mockStorage({ size: 1234 }) }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.storagePath, storagePath);
    assert.ok(res.body.resultUrl.includes("download"));
    assert.equal(res.body.previewUrl, res.body.resultUrl);
    assert.equal(res.body.namespace, "prod");
    assert.ok(store.signed.some((s) => s.action === "read"));
  });

  it("returns signed PUT grant shape", async () => {
    const { res, store } = await call(baseInit);
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.operation, "artifact_upload_init");
    assert.equal(res.body.method, "PUT");
    assert.ok(res.body.uploadUrl.includes("https://storage.googleapis.com/"));
    assert.ok(res.body.uploadUrl.includes("X-Goog-Signature="));
    assert.equal(
      res.body.storagePath,
      "sotong24/artifacts/test/wi_test_remote_e2e_1786792704742/draft/r2/07_draft_e2e_result_r2.md"
    );
    assert.equal(
      res.body.requiredHeaders["Content-Type"],
      "text/markdown; charset=utf-8"
    );
    assert.ok(res.body.artifactId);
    assert.ok(res.body.expiresAt);
    const exp = Date.parse(res.body.expiresAt);
    assert.ok(Number.isFinite(exp));
    const delta = exp - Date.now();
    assert.ok(delta > 0 && delta <= UPLOAD_URL_TTL_MS + 5000);
    assert.equal(store.signed[0].action, "write");
    assert.equal(store.signed[0].contentType, "text/markdown; charset=utf-8");
  });

  it("AI explicit fixture with stageNumber 0 derives idea_clarify order=1", async () => {
    const { res } = await call(aiExplicitInit);
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.stageId, "idea_clarify");
    assert.equal(res.body.revision, 1);
    assert.equal(
      res.body.storagePath,
      "sotong24/artifacts/test/wi_test_remote_e2e_codex_1786877899287/idea_clarify/r1/codex_ai_smoke.md"
    );
  });

  it("allows arbitrary valid ebook workflow stage (materials_prep)", async () => {
    const { res } = await call({
      ...baseInit,
      instructionId: "wi_test_remote_e2e_ai_stage_check",
      stageId: "materials_prep",
      stageNumber: 3,
      revision: 1,
      fileName: "materials_note.md",
      sizeBytes: 64,
    });
    assert.equal(res.statusCode, 200);
    assert.ok(res.body.storagePath.includes("/materials_prep/r1/"));
  });

  it("allows omitting stageNumber for ebook (derive from stageId)", async () => {
    const body = { ...aiExplicitInit };
    delete body.stageNumber;
    const { res } = await call(body);
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.stageId, "idea_clarify");
  });

  it("allows revision=1", async () => {
    const { res } = await call({
      ...baseInit,
      revision: 1,
      fileName: "07_draft_e2e_result_r1.md",
    });
    assert.equal(res.statusCode, 200);
    assert.ok(res.body.storagePath.includes("/r1/"));
  });

  it("rejects unknown ebook stageId", async () => {
    const { res } = await call({
      ...baseInit,
      stageId: "not_a_real_stage",
      stageNumber: 1,
    });
    assert.equal(res.statusCode, 400);
    assert.equal(res.body.code, "invalid_argument");
    assert.match(String(res.body.message || ""), /unknown_ebook_stageId/);
  });

  it("rejects stageNumber mismatch when explicitly provided", async () => {
    const { res } = await call({
      ...baseInit,
      stageId: "idea_clarify",
      stageNumber: 7,
    });
    assert.equal(res.statusCode, 400);
    assert.match(String(res.body.message || ""), /stageNumber_mismatch/);
  });

  it("rejects absolute path as fileName", async () => {
    const { res } = await call({
      ...baseInit,
      fileName: "C:\\Users\\a.md",
    });
    assert.equal(res.statusCode, 400);
  });

  it("rejects forbidden credential fileName", async () => {
    const { res } = await call({
      ...baseInit,
      fileName: "service-account.md",
    });
    assert.equal(res.statusCode, 400);
  });

  it("rejects invalid revision", async () => {
    const { res } = await call({
      ...baseInit,
      revision: 0,
    });
    assert.equal(res.statusCode, 400);
  });

  it("duplicate init is deterministic (same path)", async () => {
    const a = await call(baseInit);
    const b = await call(baseInit);
    assert.equal(a.res.body.storagePath, b.res.body.storagePath);
    assert.equal(a.res.body.artifactId, b.res.body.artifactId);
  });

  it("rejects oversized artifact", async () => {
    const { res } = await call({
      ...baseInit,
      sizeBytes: ARTIFACT_MAX_BYTES + 1,
    });
    assert.equal(res.statusCode, 413);
    assert.equal(res.body.code, "artifact_too_large");
  });

  it("rejects invalid contentType", async () => {
    const { res } = await call({
      ...baseInit,
      contentType: "application/octet-stream",
    });
    assert.equal(res.statusCode, 400);
    assert.equal(res.body.code, "invalid_artifact");
  });

  it("rejects filename traversal via HTTP", async () => {
    const { res } = await call({
      ...baseInit,
      fileName: "../escape.md",
    });
    assert.equal(res.statusCode, 400);
  });

  it("503 when storage signer missing", async () => {
    const res = mockRes();
    const req = mockReq({
      body: baseInit,
      headers: { Authorization: `Bearer ${SECRET}` },
    });
    await handleRelayRequest(req, res, {
      getSecret: () => SECRET,
      db: createMockDb(),
    });
    assert.equal(res.statusCode, 503);
    assert.equal(res.body.code, "failed-precondition");
  });

  it("does not put raw signature in safe log helper", () => {
    const masked = maskSignedUrlForLog(
      "https://storage.googleapis.com/b/o?X-Goog-Signature=SUPERSECRET"
    );
    assert.ok(masked.includes("REDACTED"));
    assert.ok(!masked.includes("SUPERSECRET"));
  });

  it("maps signBlob permission errors to safe code", () => {
    const mapped = mapArtifactStorageError(
      new Error(
        "Permission 'iam.serviceAccounts.signBlob' denied on resource"
      )
    );
    assert.equal(mapped.code, "artifact_signing_permission_denied");
    assert.equal(mapped.httpStatus, 503);
  });

  it("returns artifact_signing_permission_denied when signUrl fails", async () => {
    const { res } = await call(baseInit, {
      storage: {
        async signUrl() {
          throw new Error(
            "Permission iam.serviceAccounts.signBlob denied on resource"
          );
        },
        async getFileMetadata() {
          return { exists: false };
        },
      },
    });
    assert.equal(res.statusCode, 503);
    assert.equal(res.body.code, "artifact_signing_permission_denied");
  });
});

describe("artifact_upload_complete", () => {
  beforeEach(() => {
    rateLimiter.reset();
  });

  const completeBody = {
    ...baseInit,
    operation: "artifact_upload_complete",
    storagePath:
      "sotong24/artifacts/test/wi_test_remote_e2e_1786792704742/draft/r2/07_draft_e2e_result_r2.md",
  };

  it("returns resultUrl/previewUrl signed GET", async () => {
    const { res, store } = await call(completeBody, {
      storage: mockStorage({ size: 312 }),
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.ok(res.body.resultUrl.includes("download"));
    assert.equal(res.body.previewUrl, res.body.resultUrl);
    assert.ok(res.body.downloadExpiresAt);
    const delta = Date.parse(res.body.downloadExpiresAt) - Date.now();
    assert.ok(delta > DOWNLOAD_URL_TTL_MS - 60_000);
    assert.ok(store.signed.some((s) => s.action === "read"));
  });

  it("404 when object missing", async () => {
    const { res } = await call(completeBody, {
      storage: mockStorage({ exists: false }),
    });
    assert.equal(res.statusCode, 404);
  });

  it("rejects storagePath mismatch", async () => {
    const { res } = await call({
      ...completeBody,
      storagePath: "sotong24/artifacts/test/wi_test_remote_e2e_1/draft/r1/x.md",
    });
    assert.equal(res.statusCode, 400);
    assert.equal(res.body.code, "invalid_artifact");
  });
});

describe("parseArtifactUploadInit", () => {
  it("parses valid TEST payload", () => {
    const p = parseArtifactUploadInit(baseInit);
    assert.equal(p.revision, 2);
    assert.ok(p.storagePath.includes("/r2/"));
  });

  it("derives stageNumber from stageId when Agent sends 0", () => {
    const p = parseArtifactUploadInit(aiExplicitInit);
    assert.equal(p.stageId, "idea_clarify");
    assert.equal(p.stageNumber, 1);
    assert.equal(p.revision, 1);
    assert.equal(p.fileName, "codex_ai_smoke.md");
    assert.equal(p.sizeBytes, 150);
  });
});

describe("artifact attachment download", () => {
  const body = {
    projectId: "wi_plan_PILOT_PDF",
    stageId: "publish_prep",
    revision: 1,
    fileName: "final_ebook.pdf",
    downloadFileName: "모바일 결제 보안 기초 전자책_r1.pdf",
  };

  it("builds a deterministic PROD path and safe UTF-8 attachment name", () => {
    const parsed = parseArtifactDownloadRequest(body);
    assert.equal(
      parsed.storagePath,
      "sotong24/artifacts/prod/wi_plan_PILOT_PDF/publish_prep/r1/final_ebook.pdf"
    );
    const disposition = buildAttachmentDisposition(parsed.downloadFileName, 1);
    assert.match(disposition, /^attachment; filename="AI_ebook_final_r1\.pdf"/);
    assert.match(disposition, /filename\*=UTF-8''/);
    assert.doesNotMatch(disposition, /[\r\n]/);
  });

  it("signs a short-lived read URL with Content-Disposition attachment", async () => {
    const parsed = parseArtifactDownloadRequest(body);
    const store = mockStorage({ size: 195078, contentType: "application/pdf" });
    const grant = await createAttachmentDownloadGrant(parsed, store, {
      now: Date.now(),
    });
    assert.equal(grant.contentType, "application/pdf");
    assert.equal(grant.sizeBytes, 195078);
    assert.ok(grant.downloadUrl.includes("download"));
    const signed = store.signed.at(-1);
    assert.equal(signed.action, "read");
    assert.match(signed.responseDisposition, /^attachment;/);
  });

  it("blocks traversal, non-PDF names, wrong MIME and missing objects", async () => {
    assert.throws(
      () => parseArtifactDownloadRequest({ ...body, fileName: "../final_ebook.pdf" }),
      /path_traversal/
    );
    assert.throws(
      () => parseArtifactDownloadRequest({ ...body, fileName: "cover.png" }),
      /download_file_not_allowed/
    );
    const parsed = parseArtifactDownloadRequest(body);
    await assert.rejects(
      () =>
        createAttachmentDownloadGrant(
          parsed,
          mockStorage({ size: 195078, contentType: "text/html" })
        ),
      /contentType_mismatch_object/
    );
    await assert.rejects(
      () => createAttachmentDownloadGrant(parsed, mockStorage({ exists: false })),
      /artifact_object_missing/
    );
  });
});
