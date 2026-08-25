"use strict";

const { httpError } = require("./http");
const { assertDownloadOwner } = require("./artifact_download");
const {
  parseArtifactDownloadRequest,
  normalizeContentType,
} = require("../sotong24/artifact");

const MAX_PDF_VIEW_BYTES = 25 * 1024 * 1024;

async function handleArtifactView(db, uid, body, deps) {
  if (
    !deps ||
    typeof deps.getFileMetadata !== "function" ||
    typeof deps.downloadFile !== "function"
  ) {
    throw httpError(503, "storage_unavailable");
  }

  const parsed = parseArtifactDownloadRequest(body);
  await assertDownloadOwner(db, uid, parsed.projectId);

  const meta = await deps.getFileMetadata(parsed.storagePath);
  if (!meta || !meta.exists) {
    throw httpError(404, "not_found", "artifact_object_missing");
  }
  const contentType = normalizeContentType(meta.contentType)
    .split(";")[0]
    .trim();
  if (contentType !== "application/pdf") {
    throw httpError(400, "invalid_artifact", "contentType_mismatch_object");
  }
  const sizeBytes = Number(meta.size || 0);
  if (
    !Number.isInteger(sizeBytes) ||
    sizeBytes < 1 ||
    sizeBytes > MAX_PDF_VIEW_BYTES
  ) {
    throw httpError(400, "invalid_artifact", "sizeBytes_out_of_range");
  }

  const bytes = await deps.downloadFile(parsed.storagePath);
  if (!Buffer.isBuffer(bytes) || bytes.length !== sizeBytes) {
    throw httpError(400, "invalid_artifact", "artifact_bytes_mismatch");
  }
  return { bytes, sizeBytes };
}

module.exports = { handleArtifactView, MAX_PDF_VIEW_BYTES };
