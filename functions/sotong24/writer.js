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
  const snap = await ref.get();
  await ref.set(stage, { merge: true });
  return { stageId: stage.stageId, created: !snap.exists };
}

async function upsertStages(db, projectId, stages) {
  const results = [];
  for (const stage of stages) {
    results.push(await upsertStage(db, projectId, stage));
  }
  return results;
}

module.exports = {
  upsertProject,
  upsertStage,
  upsertStages,
};
