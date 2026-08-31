"use strict";

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("crypto");
const {
  maybeEnqueueApkReadyForDeviceReview,
  verifyStoredSha256,
} = require("../sotong24/apk_ready");
const { notificationKey } = require("../remote/monitoring");

function createMockDb() {
  const store = new Map();
  function collectionRef(name) {
    return {
      doc(id) {
        return {
          async get() {
            const key = `${name}/${id}`;
            return {
              exists: store.has(key),
              data: () => store.get(key),
            };
          },
          collection(sub) {
            return collectionRef(`${name}/${id}/${sub}`);
          },
        };
      },
      where() {
        return {
          limit() {
            return {
              async get() {
                return { docs: [] };
              },
            };
          },
        };
      },
    };
  }
  return {
    store,
    collection: collectionRef,
    runTransaction(fn) {
      const tx = {
        async get(ref) {
          const key = `${ref._col}/${ref._id}`;
          return {
            exists: store.has(key),
            data: () => store.get(key),
          };
        },
        async set(ref, data) {
          store.set(`${ref._col}/${ref._id}`, data);
        },
      };
      return fn(tx);
    },
  };
}

function txRef(col, id) {
  return { _col: col, _id: id };
}

describe("apk_ready_for_device_review gate", () => {
  it("skips historical prelaunch_review projects unless replayTest", async () => {
    const db = createMockDb();
    db.store.set("sotong24work_projects/wi_plan_test", {
      productionStatus: "prelaunch_review",
      title: "테스트앱",
      ownerUid: "uid_a",
    });
    const parsed = {
      instructionId: "wi_plan_test",
      productType: "app",
      stageId: "app_android_release",
      stageNumber: 14,
      revision: 1,
      namespace: "prod",
      isTest: false,
      fileName: "app-release_r1.apk",
      storagePath: "sotong24/artifacts/prod/wi_plan_test/app_android_release/r1/app-release_r1.apk",
      sizeBytes: 1000,
      sha256: "a".repeat(64),
    };
    const out = await maybeEnqueueApkReadyForDeviceReview(
      db,
      parsed,
      { ok: true, artifactId: "art1" },
      {
        async createAttachmentDownloadGrant() {
          return {
            downloadUrl: "https://example.test/apk",
            sizeBytes: 1000,
            contentType: "application/vnd.android.package-archive",
          };
        },
        createReadStream() {
          const hash = crypto.createHash("sha256");
          hash.update(Buffer.alloc(1000, 1));
          const digest = hash.digest();
          return {
            on(ev, cb) {
              if (ev === "data") cb(digest);
              if (ev === "end") cb();
            },
          };
        },
      },
      {}
    );
    assert.equal(out.skipped, "historical_prelaunch_project");
  });

  it("dedup key includes artifactId and eventType", () => {
    const key = notificationKey({
      ownerUid: "u1",
      instructionId: "wi_plan_x",
      jobId: "job_x",
      stageId: "app_android_release",
      revision: 1,
      eventType: "apk_ready_for_device_review",
      artifactId: "artifact_a",
    });
    const dup = notificationKey({
      ownerUid: "u1",
      instructionId: "wi_plan_x",
      jobId: "job_x",
      stageId: "app_android_release",
      revision: 1,
      eventType: "apk_ready_for_device_review",
      artifactId: "artifact_a",
    });
    const other = notificationKey({
      ownerUid: "u1",
      instructionId: "wi_plan_x",
      jobId: "job_x",
      stageId: "app_android_release",
      revision: 1,
      eventType: "apk_ready_for_device_review",
      artifactId: "artifact_b",
    });
    assert.equal(key, dup);
    assert.notEqual(key, other);
  });

  it("verifyStoredSha256 streams hash", async () => {
    const bytes = Buffer.from("apk-fixture");
    const expected = crypto.createHash("sha256").update(bytes).digest("hex");
    const out = await verifyStoredSha256(
      { sha256: expected, storagePath: "x" },
      {
        createReadStream() {
          return {
            on(ev, cb) {
              if (ev === "data") cb(bytes);
              if (ev === "end") cb();
            },
          };
        },
      }
    );
    assert.equal(out.ok, true);
    assert.equal(out.reason, "match");
  });
});
