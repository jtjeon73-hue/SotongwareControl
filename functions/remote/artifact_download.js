"use strict";

const { COL } = require("./constants");
const { httpError } = require("./http");
const {
  parseArtifactDownloadRequest,
  createAttachmentDownloadGrant,
} = require("../sotong24/artifact");

async function assertDownloadOwner(db, uid, projectId) {
  const projectSnap = await db.collection(COL.PROJECTS).doc(projectId).get();
  if (!projectSnap.exists) {
    throw httpError(404, "not_found", "project_not_found");
  }
  const project = projectSnap.data() || {};
  if (project.isDemo === true) {
    throw httpError(403, "forbidden", "demo_project_blocked");
  }
  const projectOwner = String(project.ownerUid || "");
  if (projectOwner) {
    if (projectOwner !== uid) {
      throw httpError(403, "forbidden", "project_owner_mismatch");
    }
    return;
  }

  // Relay-originated legacy projects do not carry ownerUid. Their authenticated
  // Control job is the ownership bridge; never authorize on projectId alone.
  const jobs = await db
    .collection(COL.JOBS)
    .where("instructionId", "==", projectId)
    .limit(20)
    .get();
  const owned = jobs.docs.some(
    (doc) => String((doc.data() || {}).ownerUid || "") === uid
  );
  if (!owned) {
    throw httpError(403, "forbidden", "artifact_owner_mismatch");
  }
}

async function handleArtifactDownload(db, uid, body, deps) {
  if (!deps || typeof deps.signUrl !== "function" || typeof deps.getFileMetadata !== "function") {
    throw httpError(503, "storage_unavailable");
  }
  let parsed;
  try {
    parsed = parseArtifactDownloadRequest(body);
    await assertDownloadOwner(db, uid, parsed.projectId);
    return await createAttachmentDownloadGrant(parsed, deps);
  } catch (err) {
    if (err && err.code && !err.error) err.error = err.code;
    throw err;
  }
}

module.exports = { handleArtifactDownload, assertDownloadOwner };
