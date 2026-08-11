"use strict";

/**
 * Firestore upsert (Admin SDK).
 * - allowlist 필드만 merge
 * - 동일 projectId/stageId 재전송 idempotent
 * - requests 컬렉션은 읽기/쓰기하지 않음 (이번 단계)
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
