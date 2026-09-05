"use strict";

/**
 * Review-only artifact delivery (owner device review).
 * Separate from prod/test Golden artifact lanes.
 *
 * Storage: sotong24/review-artifacts/{instructionId}/r{N}/{fileName}
 * Metadata: sotong24_review_artifacts/{instructionId}__r{N}
 */

const crypto = require("crypto");
const { assertSafeId, reject } = require("./validate");
const {
  APK_ARTIFACT_MIN_BYTES,
  APK_ARTIFACT_MAX_BYTES,
  ATTACHMENT_URL_TTL_MS,
  UPLOAD_URL_TTL_MS,
  sanitizeFileName,
  sanitizeDownloadFileName,
  buildAttachmentDisposition,
  normalizeContentType,
  createUploadGrant,
  createAttachmentDownloadGrant,
  scrubErrorText,
} = require("./artifact");

const REVIEW_ARTIFACTS_PREFIX = "sotong24/review-artifacts/";
const REVIEW_ARTIFACTS_COL = "sotong24_review_artifacts";
const APK_CONTENT_TYPE = "application/vnd.android.package-archive";

function normalizeRevision(raw) {
  if (raw === undefined || raw === null || raw === "") {
    reject("invalid_argument", "revision required");
  }
  if (typeof raw === "number" && Number.isInteger(raw) && raw >= 1 && raw <= 999) {
    return raw;
  }
  const s = String(raw).trim().toUpperCase();
  const m = /^R(\d{1,3})$/.exec(s) || /^(\d{1,3})$/.exec(s);
  if (!m) reject("invalid_argument", "revision invalid");
  const n = Number(m[1]);
  if (!Number.isInteger(n) || n < 1 || n > 999) {
    reject("invalid_argument", "revision out_of_range");
  }
  return n;
}

function revisionLabel(revision) {
  return `R${revision}`;
}

function assertSha256(raw, field = "sha256") {
  const s = String(raw || "")
    .trim()
    .toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(s)) {
    reject("invalid_argument", `${field} invalid`);
  }
  return s;
}

function buildReviewArtifactStoragePath({ instructionId, revision, fileName }) {
  const id = assertSafeId(instructionId, "instructionId");
  const rev = normalizeRevision(revision);
  const name = sanitizeFileName(fileName);
  if (!name.toLowerCase().endsWith(".apk")) {
    reject("invalid_artifact", "review_apk_required");
  }
  const expected = `app-release_r${rev}.apk`;
  if (name !== expected) {
    reject("invalid_artifact", "review_filename_mismatch");
  }
  return `${REVIEW_ARTIFACTS_PREFIX}${id}/r${rev}/${name}`;
}

function reviewArtifactDocId(instructionId, revision) {
  const id = assertSafeId(instructionId, "instructionId");
  const rev = normalizeRevision(revision);
  return `${id}__r${rev}`;
}

function parseReviewArtifactUploadInit(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    reject("invalid_argument", "body required");
  }
  const instructionId = assertSafeId(body.instructionId, "instructionId");
  const revision = normalizeRevision(body.revision);
  const fileName = sanitizeFileName(body.fileName || `app-release_r${revision}.apk`);
  const contentType = normalizeContentType(body.contentType || APK_CONTENT_TYPE);
  if (contentType.split(";")[0].trim() !== APK_CONTENT_TYPE) {
    reject("invalid_artifact", "contentType_mismatch_extension");
  }
  const sizeBytes = Number(body.sizeBytes);
  if (!Number.isInteger(sizeBytes) || sizeBytes < APK_ARTIFACT_MIN_BYTES) {
    reject("invalid_artifact", "apk_size_below_minimum");
  }
  if (sizeBytes > APK_ARTIFACT_MAX_BYTES) {
    reject("artifact_too_large", "sizeBytes exceeds_limit", 413);
  }
  const sha256 = assertSha256(body.sha256, "sha256");
  const storagePath = buildReviewArtifactStoragePath({
    instructionId,
    revision,
    fileName,
  });
  if (body.storagePath !== undefined && body.storagePath !== null && body.storagePath !== "") {
    if (String(body.storagePath).trim() !== storagePath) {
      reject("invalid_artifact", "storagePath_mismatch");
    }
  }
  const ownerUid =
    body.ownerUid !== undefined && body.ownerUid !== null && String(body.ownerUid).trim()
      ? assertSafeId(String(body.ownerUid).trim(), "ownerUid")
      : "";
  const artifactType = String(body.artifactType || "app").trim() || "app";
  if (artifactType !== "app") {
    reject("invalid_argument", "artifactType unsupported");
  }
  const artifactId = crypto
    .createHash("sha256")
    .update(`${storagePath}|${sha256}|${sizeBytes}`)
    .digest("hex")
    .slice(0, 32);

  return {
    instructionId,
    revision,
    revisionLabel: revisionLabel(revision),
    fileName,
    contentType: APK_CONTENT_TYPE,
    sizeBytes,
    sha256,
    storagePath,
    artifactId,
    ownerUid,
    artifactType,
    reviewOnly: true,
    maxBytes: APK_ARTIFACT_MAX_BYTES,
  };
}

function parseReviewArtifactUploadComplete(body) {
  return parseReviewArtifactUploadInit(body);
}

function parseReviewArtifactDownloadRequest(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    reject("invalid_argument", "body required");
  }
  const instructionId = assertSafeId(
    body.instructionId || body.projectId,
    "instructionId"
  );
  const revision = normalizeRevision(body.revision);
  const artifactSha256 = assertSha256(
    body.artifactSha256 || body.sha256,
    "artifactSha256"
  );
  const fileName = sanitizeFileName(
    body.fileName || `app-release_r${revision}.apk`
  );
  const expected = `app-release_r${revision}.apk`;
  if (fileName !== expected) {
    reject("invalid_artifact", "review_filename_mismatch");
  }
  const storagePath = buildReviewArtifactStoragePath({
    instructionId,
    revision,
    fileName,
  });
  // Block any attempt to pass a different storage path.
  if (body.storagePath) {
    reject("invalid_artifact", "storagePath_not_allowed");
  }
  return {
    instructionId,
    revision,
    revisionLabel: revisionLabel(revision),
    fileName,
    artifactSha256,
    storagePath,
    productType: "app",
    contentType: APK_CONTENT_TYPE,
    downloadFileName: sanitizeDownloadFileName(
      body.downloadFileName,
      revision,
      ".apk"
    ),
    reviewOnly: true,
  };
}

function isReviewDownloadEligible(prs) {
  if (!prs || typeof prs !== "object") return false;
  const tv = prs.technicalValidation || {};
  const readiness = prs.readiness || {};
  const owner = prs.ownerReview || {};
  const techDone =
    tv.completed === true || readiness.technicalValidationCompleted === true;
  if (!techDone) return false;
  const decision = String(owner.decision || "").trim();
  const waiting =
    decision === "pending" ||
    decision === "changes_requested" ||
    readiness.ownerReviewRequired === true;
  return waiting;
}

function assertPrsMatchesReview(prs, parsed) {
  if (!prs) {
    reject("failed-precondition", "production_review_status_missing", 404);
  }
  const prsRevision = normalizeRevision(prs.revision || (prs.ownerReview || {}).revision);
  if (prsRevision !== parsed.revision) {
    reject("forbidden", "review_revision_mismatch", 403);
  }
  const prsSha = String(
    (prs.technicalValidation && prs.technicalValidation.artifactSha256) || ""
  )
    .trim()
    .toLowerCase();
  if (prsSha !== parsed.artifactSha256) {
    reject("forbidden", "review_sha256_mismatch", 403);
  }
  if (!isReviewDownloadEligible(prs)) {
    reject("failed-precondition", "review_not_downloadable", 409);
  }
}

async function verifyStoredSha256(storagePath, expectedSha, deps) {
  const want = String(expectedSha || "")
    .trim()
    .toLowerCase();
  const hash = crypto.createHash("sha256");
  if (typeof deps.createReadStream === "function") {
    await new Promise((resolve, rejectStream) => {
      const stream = deps.createReadStream(storagePath);
      stream.on("data", (chunk) => hash.update(chunk));
      stream.on("end", resolve);
      stream.on("error", rejectStream);
    });
  } else if (typeof deps.downloadFile === "function") {
    hash.update(await deps.downloadFile(storagePath));
  } else {
    reject("failed-precondition", "sha_read_unavailable", 503);
  }
  const got = hash.digest("hex").toLowerCase();
  if (got !== want) {
    reject("forbidden", "stored_sha256_mismatch", 403);
  }
  return got;
}

async function writeReviewArtifactMetadata(db, parsed, { nowIso } = {}) {
  const docId = reviewArtifactDocId(parsed.instructionId, parsed.revision);
  const createdAt = nowIso || new Date().toISOString();
  const payload = {
    instructionId: parsed.instructionId,
    revision: parsed.revision,
    revisionLabel: parsed.revisionLabel || revisionLabel(parsed.revision),
    artifactType: parsed.artifactType || "app",
    fileName: parsed.fileName,
    sizeBytes: parsed.sizeBytes,
    sha256: parsed.sha256,
    storagePath: parsed.storagePath,
    artifactId: parsed.artifactId || "",
    ownerUid: parsed.ownerUid || "",
    reviewOnly: true,
    createdAt,
    updatedAt: createdAt,
  };
  await db.collection(REVIEW_ARTIFACTS_COL).doc(docId).set(payload, { merge: true });
  return { docId, ...payload };
}

async function readReviewArtifactMetadata(db, instructionId, revision) {
  const docId = reviewArtifactDocId(instructionId, revision);
  const snap = await db.collection(REVIEW_ARTIFACTS_COL).doc(docId).get();
  if (!snap.exists) return null;
  return { docId, ...(snap.data() || {}) };
}

module.exports = {
  REVIEW_ARTIFACTS_PREFIX,
  REVIEW_ARTIFACTS_COL,
  normalizeRevision,
  revisionLabel,
  buildReviewArtifactStoragePath,
  reviewArtifactDocId,
  parseReviewArtifactUploadInit,
  parseReviewArtifactUploadComplete,
  parseReviewArtifactDownloadRequest,
  isReviewDownloadEligible,
  assertPrsMatchesReview,
  verifyStoredSha256,
  writeReviewArtifactMetadata,
  readReviewArtifactMetadata,
  createUploadGrant,
  createAttachmentDownloadGrant,
  buildAttachmentDisposition,
  ATTACHMENT_URL_TTL_MS,
  UPLOAD_URL_TTL_MS,
  scrubErrorText,
};
