"use strict";

/**
 * Firestore upsert (Admin SDK).
 * - allowlist 필드만 merge
 * - 동일 projectId/stageId 재전송 idempotent
 * - requests 쓰기는 하지 않음 (request_poll은 reader.js 읽기 전용)
 */
async function upsertProject(db, project) {
  const ref = db.collection("sotong24work_projects").doc(project.projectId);
  const snap = await ref.get();
  const payload = { ...project };
  if (!snap.exists) {
    payload.createdAt = project.serverReceivedAt || project.updatedAt;
  }
  await ref.set(payload, { merge: true });
  return { projectId: project.projectId, created: !snap.exists };
}

async function upsertStage(db, projectId, stage) {
  const ref = db
    .collection("sotong24work_projects")
    .doc(projectId)
    .collection("stages")
    .doc(stage.stageId);
  let created = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    created = !snap.exists;
    const previous = snap.exists ? snap.data() || {} : {};
    const payload = { ...stage };
    const terminalDecision = new Set(["approved", "revision_requested"]);
    const previousRevision = Math.max(1, Number(previous.revision) || 1);
    const incomingRevision = Math.max(1, Number(stage.revision) || 1);
    const sameRevision = incomingRevision === previousRevision;
    if (
      stage.status === "awaiting_approval" &&
      stage.approvalStatus === "pending" &&
      terminalDecision.has(String(previous.approvalStatus || "")) &&
      sameRevision
    ) {
      payload.approvalStatus = previous.approvalStatus;
      if (previous.activeRequestId) {
        payload.activeRequestId = previous.activeRequestId;
      }
    }
    tx.set(ref, payload, { merge: true });
  });
  return { stageId: stage.stageId, created };
}

async function upsertStages(db, projectId, stages) {
  const results = [];
  for (const stage of stages) {
    results.push(await upsertStage(db, projectId, stage));
  }
  return results;
}

async function markRequestWorkflowApplied(db, receipt, appliedAt) {
  const ref = db
    .collection("sotong24work_projects")
    .doc(receipt.projectId)
    .collection("requests")
    .doc(receipt.requestId);
  let idempotent = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      const error = new Error("request_not_found");
      error.code = "not-found";
      error.httpStatus = 404;
      throw error;
    }
    const current = snap.data() || {};
    if (String(current.projectId || "") !== receipt.projectId ||
        String(current.stageId || "") !== receipt.completedStageId) {
      const error = new Error("request_identity_mismatch");
      error.code = "failed-precondition";
      error.httpStatus = 409;
      throw error;
    }
    if (current.status !== "approved" && current.status !== "revision_requested") {
      const error = new Error("request_decision_not_terminal");
      error.code = "failed-precondition";
      error.httpStatus = 409;
      throw error;
    }
    if (current.workflowApplied === true) {
      idempotent = true;
      if (String(current.completedStageId || "") !== receipt.completedStageId ||
          String(current.nextStageIdPrepared || "") !== receipt.nextStageIdPrepared) {
        const error = new Error("workflow_receipt_conflict");
        error.code = "already-exists";
        error.httpStatus = 409;
        throw error;
      }
      return;
    }
    tx.set(ref, {
      processed: true,
      workflowApplied: true,
      workflowAppliedAt: appliedAt,
      completedStageId: receipt.completedStageId,
      nextStageIdPrepared: receipt.nextStageIdPrepared,
      updatedAt: appliedAt,
    }, { merge: true });
  });
  return { idempotent };
}

module.exports = {
  upsertProject,
  upsertStage,
  upsertStages,
  markRequestWorkflowApplied,
};
