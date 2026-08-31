"use strict";

const crypto = require("crypto");
const { COL } = require("../remote/constants");
const {
  loadPolicy,
  enqueueNotification,
  deliverNotificationEvent,
} = require("../remote/monitoring");
const {
  createAttachmentDownloadGrant,
  parseArtifactDownloadRequest,
  APK_ARTIFACT_MIN_BYTES,
  APK_ARTIFACT_MAX_BYTES,
} = require("./artifact");
const { getProjectDoc } = require("./reader");

async function resolveOwnerUid(db, instructionId) {
  const project = await getProjectDoc(db, instructionId);
  if (project && project.ownerUid) return String(project.ownerUid);
  const jobs = await db
    .collection(COL.JOBS)
    .where("instructionId", "==", instructionId)
    .limit(10)
    .get();
  for (const doc of jobs.docs) {
    const owner = String((doc.data() || {}).ownerUid || "");
    if (owner) return owner;
  }
  return "";
}

async function verifyDownloadGrant(parsed, deps) {
  const downloadParsed = parseArtifactDownloadRequest({
    projectId: parsed.instructionId,
    stageId: parsed.stageId,
    revision: parsed.revision,
    productType: "app",
    fileName: parsed.fileName,
    downloadFileName: parsed.fileName,
  });
  return createAttachmentDownloadGrant(downloadParsed, deps);
}

async function verifyStoredSha256(parsed, deps) {
  const expected = String(parsed.sha256 || "").trim().toLowerCase();
  if (!expected || expected.length !== 64) {
    return { ok: true, skipped: "sha256_not_provided" };
  }
  const hash = crypto.createHash("sha256");
  if (typeof deps.createReadStream === "function") {
    await new Promise((resolve, reject) => {
      const stream = deps.createReadStream(parsed.storagePath);
      stream.on("data", (chunk) => hash.update(chunk));
      stream.on("end", resolve);
      stream.on("error", reject);
    });
  } else if (typeof deps.downloadFile === "function") {
    hash.update(await deps.downloadFile(parsed.storagePath));
  } else {
    return { ok: false, reason: "sha_read_unavailable" };
  }
  const got = hash.digest("hex").toLowerCase();
  return {
    ok: got === expected,
    reason: got === expected ? "match" : "sha256_mismatch",
  };
}

/**
 * After prod app_android_release artifact_upload_complete:
 * verify attachment download + optional sha256, then enqueue APK_READY once.
 * Skips historical projects already in prelaunch_review unless replayTest=true.
 */
async function maybeEnqueueApkReadyForDeviceReview(
  db,
  parsed,
  finalizeResult,
  deps,
  { messaging, replayTest = false } = {}
) {
  if (parsed.productType !== "app") return { skipped: "not_app" };
  if (parsed.stageId !== "app_android_release") return { skipped: "not_release_stage" };
  if (parsed.namespace !== "prod" || parsed.isTest) return { skipped: "not_prod_lane" };
  if (!finalizeResult || !finalizeResult.ok) return { skipped: "finalize_not_ok" };

  const project = await getProjectDoc(db, parsed.instructionId);
  const productionStatus = String((project && project.productionStatus) || "");
  if (
    !replayTest &&
    (productionStatus === "prelaunch_review" ||
      productionStatus === "production_complete")
  ) {
    return { skipped: "historical_prelaunch_project" };
  }

  const grant = await verifyDownloadGrant(parsed, deps);
  if (!grant.downloadUrl || !grant.sizeBytes) {
    return { skipped: "download_grant_failed" };
  }
  if (grant.sizeBytes !== parsed.sizeBytes) {
    return { skipped: "download_size_mismatch" };
  }
  if (grant.contentType !== "application/vnd.android.package-archive") {
    return { skipped: "download_content_type_mismatch" };
  }

  const sha = await verifyStoredSha256(parsed, deps);
  if (!sha.ok) {
    return { skipped: sha.reason || "sha256_verify_failed" };
  }

  const ownerUid = await resolveOwnerUid(db, parsed.instructionId);
  if (!ownerUid) return { skipped: "owner_missing" };

  const policy = await loadPolicy(db);
  const artifactId = String(
    finalizeResult.artifactId || parsed.artifactId || ""
  ).trim();
  const appName = String((project && project.title) || "앱").slice(0, 120);

  const out = await enqueueNotification(
    db,
    {
      ownerUid,
      instructionId: parsed.instructionId,
      jobId: String((project && project.jobId) || ""),
      stageId: parsed.stageId,
      stageNumber: parsed.stageNumber || 14,
      stageName: "Android Release Build",
      revision: parsed.revision || 1,
      eventType: "apk_ready_for_device_review",
      productType: "app",
      appName,
      artifactId,
      storagePath: parsed.storagePath,
      sizeBytes: parsed.sizeBytes,
      severity: "info",
      actionRequired: true,
      source: replayTest ? "apk_ready_replay_test" : "artifact_upload_complete",
      idempotencyDiscriminator: artifactId || parsed.storagePath,
      nowMs: Date.now(),
    },
    policy
  );

  let delivery = { delivered: 0, skipped: "not_created" };
  if (out.created && policy.notificationDeliveryMode === "fcm" && messaging) {
    delivery = await deliverNotificationEvent(db, messaging, out.id);
  }

  return {
    skipped: null,
    notificationEventId: out.id,
    created: out.created,
    delivery,
    downloadVerified: true,
    sha256Verified: sha.skipped ? "skipped" : sha.reason,
  };
}

module.exports = {
  maybeEnqueueApkReadyForDeviceReview,
  verifyDownloadGrant,
  verifyStoredSha256,
  resolveOwnerUid,
};
