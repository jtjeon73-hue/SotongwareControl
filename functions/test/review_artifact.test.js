"use strict";

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("crypto");
const { handleApiRequest } = require("../remote/router");
const { createMemoryDb } = require("../remote/memory_db");
const { COL } = require("../remote/constants");
const {
  parseReviewArtifactUploadInit,
  parseReviewArtifactDownloadRequest,
  buildReviewArtifactStoragePath,
  isReviewDownloadEligible,
  REVIEW_ARTIFACTS_COL,
} = require("../sotong24/review_artifact");
const { parseArtifactDownloadRequest } = require("../sotong24/artifact");
const { handleRelayRequest } = require("../sotong24/relay");

const SHA_R2 = "3c5d16c7d74bbce525ffe053a1037264f346173299c3f0c769618d0e3ca3ac5c";
const SHA_R1 = "6c151c739ca1fd9eb9ff7ac631396db677083004af48d67344c9785fa120c481";
const IID = "wi_test_cursor_app_step15_1788441053773";

function mockRes() {
  return {
    statusCode: 0,
    body: null,
    headers: {},
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

async function callApi(db, path, body, { uid = "owner_uid", depsExtra = {} } = {}) {
  const res = mockRes();
  const req = mockReq({
    path,
    body,
    headers: { Authorization: `Bearer uid:${uid}` },
  });
  await handleApiRequest(req, res, {
    db,
    verifyIdToken: async () => ({ uid, email: "t@test.com" }),
    ...depsExtra,
  });
  return res;
}

function seedPrs(db, overrides = {}) {
  db.store.set(`production_review_status/${IID}`, {
    instructionId: IID,
    projectId: "farm_safety_check",
    revision: "R2",
    displayTitle: "농작업 안전 점검",
    technicalValidation: {
      completed: true,
      artifactSha256: SHA_R2,
      artifactKind: "android_apk",
    },
    ownerReview: {
      decision: "pending",
      revision: "R2",
      step16Blocked: true,
    },
    readiness: {
      technicalValidationCompleted: true,
      ownerReviewRequired: true,
      registrationEligible: false,
      externalPublicationAllowed: false,
    },
    userLabelKo: "기술검증 완료 · 사용자 검토 대기",
    ...overrides,
  });
}

function seedMeta(db, overrides = {}) {
  const path = `sotong24/review-artifacts/${IID}/r2/app-release_r2.apk`;
  db.store.set(`${REVIEW_ARTIFACTS_COL}/${IID}__r2`, {
    instructionId: IID,
    revision: 2,
    revisionLabel: "R2",
    artifactType: "app",
    fileName: "app-release_r2.apk",
    sizeBytes: 53079965,
    sha256: SHA_R2,
    storagePath: path,
    ownerUid: "owner_uid",
    reviewOnly: true,
    createdAt: "2026-09-04T00:00:00.000Z",
    ...overrides,
  });
  return path;
}

function storageDeps(apkBytes, expectedPath) {
  return {
    async getFileMetadata(path) {
      assert.equal(path, expectedPath);
      return {
        exists: true,
        size: apkBytes.length,
        contentType: "application/vnd.android.package-archive",
      };
    },
    async signUrl(args) {
      assert.equal(args.path, expectedPath);
      return `https://storage.googleapis.com/bucket/${args.path}?X-Goog-Signature=test`;
    },
    async downloadFile(path) {
      assert.equal(path, expectedPath);
      return apkBytes;
    },
    createReadStream(path) {
      assert.equal(path, expectedPath);
      const { Readable } = require("stream");
      return Readable.from([apkBytes]);
    },
  };
}

describe("review artifact contract", () => {
  let db;

  beforeEach(() => {
    db = createMemoryDb();
  });

  it("builds isolated review storage path (not prod/test lane)", () => {
    const p = buildReviewArtifactStoragePath({
      instructionId: IID,
      revision: "R2",
      fileName: "app-release_r2.apk",
    });
    assert.equal(p, `sotong24/review-artifacts/${IID}/r2/app-release_r2.apk`);
    assert.ok(!p.includes("/artifacts/prod/"));
    assert.ok(!p.includes("/artifacts/test/"));
  });

  it("rejects wrong revision filename on upload parse", () => {
    assert.throws(
      () =>
        parseReviewArtifactUploadInit({
          instructionId: IID,
          revision: 2,
          fileName: "app-release_r1.apk",
          contentType: "application/vnd.android.package-archive",
          sizeBytes: 2 * 1024 * 1024,
          sha256: SHA_R2,
        }),
      /review_filename_mismatch/
    );
  });

  it("allows download while registration/external publish are false", () => {
    assert.equal(
      isReviewDownloadEligible({
        technicalValidation: { completed: true },
        ownerReview: { decision: "pending" },
        readiness: {
          technicalValidationCompleted: true,
          ownerReviewRequired: true,
          registrationEligible: false,
          externalPublicationAllowed: false,
        },
      }),
      true
    );
  });

  it("does not weaken Golden wi_plan_* artifact-download parser", () => {
    const golden = parseArtifactDownloadRequest({
      projectId: "wi_plan_APP_FOUNDATION",
      productType: "app",
      stageId: "app_production_complete",
      revision: 2,
      fileName: "app-release_r2.apk",
      downloadFileName: "App_r2.apk",
    });
    assert.match(golden.storagePath, /\/artifacts\/prod\//);
    assert.throws(
      () =>
        parseArtifactDownloadRequest({
          projectId: IID,
          productType: "app",
          stageId: "app_production_complete",
          revision: 2,
          fileName: "app-release_r2.apk",
        }),
      /wi_plan_/
    );
  });

  it("unauthenticated review download is blocked", async () => {
    seedPrs(db);
    seedMeta(db);
    const res = mockRes();
    const req = mockReq({
      path: "/api/control/review-artifact-download",
      body: {
        instructionId: IID,
        revision: "R2",
        artifactSha256: SHA_R2,
      },
    });
    await handleApiRequest(req, res, {
      db,
      verifyIdToken: async () => {
        throw new Error("no");
      },
    });
    assert.equal(res.statusCode, 401);
  });

  it("owner grant succeeds when PRS + metadata + object SHA match", async () => {
    seedPrs(db);
    const path = seedMeta(db);
    const bytes = Buffer.alloc(128 * 1024, 7);
    // Force metadata/object size alignment for grant size check; SHA verified via stream of these bytes
    // Use SHA of these bytes for this unit path:
    const sha = crypto.createHash("sha256").update(bytes).digest("hex");
    db.store.set(`production_review_status/${IID}`, {
      ...db.store.get(`production_review_status/${IID}`),
      technicalValidation: { completed: true, artifactSha256: sha },
    });
    db.store.set(`${REVIEW_ARTIFACTS_COL}/${IID}__r2`, {
      ...db.store.get(`${REVIEW_ARTIFACTS_COL}/${IID}__r2`),
      sha256: sha,
      sizeBytes: bytes.length,
    });

    const res = await callApi(
      db,
      "/api/control/review-artifact-download",
      {
        instructionId: IID,
        revision: 2,
        artifactSha256: sha,
        downloadFileName: "FarmSafety_r2.apk",
      },
      { uid: "owner_uid", depsExtra: storageDeps(bytes, path) }
    );
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.contentType, "application/vnd.android.package-archive");
    assert.equal(res.body.sizeBytes, bytes.length);
    assert.ok(String(res.body.downloadUrl).includes("storage.googleapis.com"));
  });

  it("blocks cross-instruction access", async () => {
    seedPrs(db);
    const path = seedMeta(db);
    const bytes = Buffer.alloc(128 * 1024, 1);
    const sha = crypto.createHash("sha256").update(bytes).digest("hex");
    db.store.set(`production_review_status/${IID}`, {
      ...db.store.get(`production_review_status/${IID}`),
      technicalValidation: { completed: true, artifactSha256: sha },
    });
    db.store.set(`${REVIEW_ARTIFACTS_COL}/${IID}__r2`, {
      ...db.store.get(`${REVIEW_ARTIFACTS_COL}/${IID}__r2`),
      sha256: sha,
      sizeBytes: bytes.length,
    });
    const res = await callApi(
      db,
      "/api/control/review-artifact-download",
      {
        instructionId: "wi_test_cursor_app_step15_OTHER",
        revision: 2,
        artifactSha256: sha,
      },
      { uid: "owner_uid", depsExtra: storageDeps(bytes, path) }
    );
    assert.ok(res.statusCode >= 400);
  });

  it("blocks wrong revision", async () => {
    seedPrs(db);
    seedMeta(db);
    const path = `sotong24/review-artifacts/${IID}/r2/app-release_r2.apk`;
    const bytes = Buffer.alloc(128 * 1024, 2);
    const res = await callApi(
      db,
      "/api/control/review-artifact-download",
      {
        instructionId: IID,
        revision: 1,
        artifactSha256: SHA_R2,
        fileName: "app-release_r1.apk",
      },
      {
        uid: "owner_uid",
        depsExtra: {
          async getFileMetadata() {
            return { exists: true, size: bytes.length, contentType: "application/vnd.android.package-archive" };
          },
          async signUrl() {
            return "https://storage.googleapis.com/x";
          },
          async downloadFile() {
            return bytes;
          },
        },
      }
    );
    assert.equal(res.statusCode, 403);
    assert.ok(
      ["review_revision_mismatch", "forbidden", "review_filename_mismatch"].includes(
        res.body.error
      ) || res.body.message
    );
  });

  it("blocks SHA mismatch", async () => {
    seedPrs(db);
    seedMeta(db);
    const path = `sotong24/review-artifacts/${IID}/r2/app-release_r2.apk`;
    const bytes = Buffer.alloc(128 * 1024, 3);
    const res = await callApi(
      db,
      "/api/control/review-artifact-download",
      {
        instructionId: IID,
        revision: "R2",
        artifactSha256: SHA_R1,
      },
      { uid: "owner_uid", depsExtra: storageDeps(bytes, path) }
    );
    assert.equal(res.statusCode, 403);
  });

  it("blocks non-owner", async () => {
    seedPrs(db);
    const path = seedMeta(db);
    const bytes = Buffer.alloc(128 * 1024, 4);
    const sha = crypto.createHash("sha256").update(bytes).digest("hex");
    db.store.set(`production_review_status/${IID}`, {
      ...db.store.get(`production_review_status/${IID}`),
      technicalValidation: { completed: true, artifactSha256: sha },
    });
    db.store.set(`${REVIEW_ARTIFACTS_COL}/${IID}__r2`, {
      ...db.store.get(`${REVIEW_ARTIFACTS_COL}/${IID}__r2`),
      sha256: sha,
      sizeBytes: bytes.length,
    });
    const res = await callApi(
      db,
      "/api/control/review-artifact-download",
      {
        instructionId: IID,
        revision: 2,
        artifactSha256: sha,
      },
      { uid: "intruder", depsExtra: storageDeps(bytes, path) }
    );
    assert.equal(res.statusCode, 403);
  });

  it("relay review upload init returns review storage path", async () => {
    const res = mockRes();
    const req = mockReq({
      path: "/",
      body: {
        operation: "review_artifact_upload_init",
        instructionId: IID,
        revision: 2,
        fileName: "app-release_r2.apk",
        contentType: "application/vnd.android.package-archive",
        sizeBytes: 2 * 1024 * 1024,
        sha256: SHA_R2,
        ownerUid: "owner_uid",
      },
      headers: { Authorization: "Bearer relay-secret" },
    });
    await handleRelayRequest(req, res, {
      db,
      getSecret: () => "relay-secret",
      async signUrl(args) {
        assert.equal(
          args.path,
          `sotong24/review-artifacts/${IID}/r2/app-release_r2.apk`
        );
        return `https://storage.googleapis.com/bucket/${args.path}?sig=1`;
      },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.reviewOnly, true);
    assert.match(res.body.storagePath, /^sotong24\/review-artifacts\//);
  });
});
