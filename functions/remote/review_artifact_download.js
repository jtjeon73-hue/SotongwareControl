"use strict";

const { COL } = require("./constants");
const { httpError } = require("./http");
const { assertDownloadOwner } = require("./artifact_download");
const {
  parseReviewArtifactDownloadRequest,
  assertPrsMatchesReview,
  readReviewArtifactMetadata,
  verifyStoredSha256,
  createAttachmentDownloadGrant,
  normalizeRevision,
} = require("../sotong24/review_artifact");

async function assertReviewDownloader(db, uid, instructionId, meta) {
  const owner = String((meta && meta.ownerUid) || "").trim();
  if (owner && owner === uid) return;

  try {
    await assertDownloadOwner(db, uid, instructionId);
    return;
  } catch (err) {
    if (err && err.httpStatus === 404) {
      // Envelope-only reviews may have no project doc — fall through to jobs.
    } else if (err && err.httpStatus === 403) {
      // continue to jobs check below
    } else {
      throw err;
    }
  }

  const jobs = await db
    .collection(COL.JOBS)
    .where("instructionId", "==", instructionId)
    .limit(20)
    .get();
  const owned = jobs.docs.some(
    (doc) => String((doc.data() || {}).ownerUid || "") === uid
  );
  if (owned) return;

  throw httpError(403, "forbidden", "review_owner_mismatch");
}

async function handleReviewArtifactDownload(db, uid, body, deps) {
  if (!deps || typeof deps.signUrl !== "function" || typeof deps.getFileMetadata !== "function") {
    throw httpError(503, "storage_unavailable");
  }

  let parsed;
  try {
    parsed = parseReviewArtifactDownloadRequest(body);
  } catch (err) {
    if (err && err.code && !err.error) err.error = err.code;
    throw err;
  }

  const prsSnap = await db
    .collection("production_review_status")
    .doc(parsed.instructionId)
    .get();
  const prs = prsSnap.exists ? prsSnap.data() || {} : null;
  try {
    assertPrsMatchesReview(prs, parsed);
  } catch (err) {
    if (err && err.code && !err.error) err.error = err.code;
    throw err;
  }

  const meta = await readReviewArtifactMetadata(
    db,
    parsed.instructionId,
    parsed.revision
  );
  if (!meta) {
    throw httpError(404, "not_found", "review_artifact_missing");
  }
  if (meta.reviewOnly !== true) {
    throw httpError(403, "forbidden", "not_review_artifact");
  }
  if (String(meta.sha256 || "").toLowerCase() !== parsed.artifactSha256) {
    throw httpError(403, "forbidden", "review_metadata_sha256_mismatch");
  }
  if (String(meta.storagePath || "") !== parsed.storagePath) {
    throw httpError(403, "forbidden", "review_storage_path_mismatch");
  }
  if (normalizeRevision(meta.revision) !== parsed.revision) {
    throw httpError(403, "forbidden", "review_metadata_revision_mismatch");
  }

  await assertReviewDownloader(db, uid, parsed.instructionId, meta);

  try {
    await verifyStoredSha256(parsed.storagePath, parsed.artifactSha256, deps);
  } catch (err) {
    if (err && err.code && !err.error) err.error = err.code;
    throw err;
  }

  const grantParsed = {
    storagePath: parsed.storagePath,
    contentType: parsed.contentType,
    productType: "app",
    downloadFileName: parsed.downloadFileName,
    revision: parsed.revision,
  };

  try {
    return await createAttachmentDownloadGrant(grantParsed, deps);
  } catch (err) {
    if (err && err.code && !err.error) err.error = err.code;
    throw err;
  }
}

module.exports = {
  handleReviewArtifactDownload,
  assertReviewDownloader,
};
