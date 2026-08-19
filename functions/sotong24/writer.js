"use strict";

/**
 * Firestore upsert (Admin SDK).
 * - allowlist 필드만 merge
 * - 동일 projectId/stageId 재전송 idempotent
 * - requests 쓰기는 하지 않음 (request_poll은 reader.js 읽기 전용)
 */
function normalizedRevision(stage) {
  return Math.max(1, Number(stage && stage.revision) || 1);
}

function terminalRank(status) {
  if (status === "completed") return 2;
  if (status === "awaiting_approval" || status === "waiting_approval") return 1;
  return 0;
}

/**
 * A full_sync can be queued before the terminal report-stage response arrives.
 * Keep the newer semantic state when that stale snapshot reaches Firestore
 * afterwards. A higher revision remains free to enter rework/in_progress.
 */
function mergeMonotonicStage(previous, incoming) {
  const prior = previous || {};
  const next = { ...incoming };
  const previousRevision = normalizedRevision(prior);
  const incomingRevision = normalizedRevision(next);
  const staleRevision = incomingRevision < previousRevision;
  const sameRevisionRegression =
    incomingRevision === previousRevision &&
    terminalRank(prior.status) > terminalRank(next.status);
  if (!staleRevision && !sameRevisionRegression) return next;

  const authoritativeFields = [
    "status",
    "criteriaMet",
    "approvalRequired",
    "approvalStatus",
    "activeRequestId",
    "revision",
    "completedAt",
    "resultUrl",
    "previewUrl",
  ];
  for (const field of authoritativeFields) {
    if (prior[field] !== undefined) next[field] = prior[field];
    else delete next[field];
  }
  return next;
}

function preserveTerminalDecision(previous, incoming, payload) {
  const terminalDecision = new Set(["approved", "revision_requested"]);
  const sameRevision = normalizedRevision(incoming) === normalizedRevision(previous);
  if (
    incoming.status === "awaiting_approval" &&
    incoming.approvalStatus === "pending" &&
    terminalDecision.has(String(previous.approvalStatus || "")) &&
    sameRevision
  ) {
    payload.approvalStatus = previous.approvalStatus;
    if (previous.activeRequestId) payload.activeRequestId = previous.activeRequestId;
  }
  return payload;
}

function alignProjectWithCurrentStage(project, stages) {
  const out = { ...project };
  const current = stages.find(
    (stage) => Number(stage.stageNumber) === Number(project.currentStage)
  );
  if (!current) return out;
  if (current.status === "awaiting_approval") {
    out.status = "awaiting_approval";
    out.approvalStatus = "pending";
  }
  return out;
}

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
    const payload = preserveTerminalDecision(
      previous,
      stage,
      mergeMonotonicStage(previous, stage)
    );
    tx.set(ref, payload, { merge: true });
  });
  return { stageId: stage.stageId, created };
}

async function upsertProjectAndStages(db, project, stages) {
  const projectRef = db.collection("sotong24work_projects").doc(project.projectId);
  const stageRefs = stages.map((stage) =>
    projectRef.collection("stages").doc(stage.stageId)
  );
  let created = false;
  let stageResults = [];
  await db.runTransaction(async (tx) => {
    // Firestore transactions require every read before the first write.
    const snapshots = await Promise.all([
      tx.get(projectRef),
      ...stageRefs.map((ref) => tx.get(ref)),
    ]);
    const projectSnap = snapshots[0];
    created = !projectSnap.exists;
    const currentStageResults = [];
    const mergedStages = stages.map((stage, index) => {
      const snap = snapshots[index + 1];
      const previous = snap.exists ? snap.data() || {} : {};
      currentStageResults.push({ stageId: stage.stageId, created: !snap.exists });
      return preserveTerminalDecision(
        previous,
        stage,
        mergeMonotonicStage(previous, stage)
      );
    });
    const projectPayload = alignProjectWithCurrentStage(project, mergedStages);
    if (created) {
      projectPayload.createdAt = project.serverReceivedAt || project.updatedAt;
    }
    tx.set(projectRef, projectPayload, { merge: true });
    mergedStages.forEach((stage, index) => {
      tx.set(stageRefs[index], stage, { merge: true });
    });
    stageResults = currentStageResults;
  });
  return {
    project: { projectId: project.projectId, created },
    stages: stageResults,
  };
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
  mergeMonotonicStage,
  upsertProject,
  upsertStage,
  upsertStages,
  upsertProjectAndStages,
  markRequestWorkflowApplied,
};
