"use strict";

const { COL } = require("./constants");
const { sha256Hex } = require("./crypto_util");
const { httpError } = require("./http");
const { nowIso } = require("./log");

const CANCEL_OPERATIONS = "cancelOperations";
const PROTECTED_AGENT_ID = "agent_9830758291f9c64e";

function text(value, max = 180) {
  return String(value || "").trim().slice(0, max);
}

function operationId(uid, jobId, instructionId) {
  return `cancel_${sha256Hex(`${uid}|${jobId}|${instructionId}`).slice(0, 32)}`;
}

async function isRunCancellationTombstoned(db, projectId) {
  const snap = await db.collection(CANCEL_OPERATIONS).get();
  return snap.docs.some((doc) => {
    const op = doc.data() || {};
    return String(op.projectId || "") === projectId &&
      ["requested", "finalizing", "completed"].includes(String(op.status || ""));
  });
}

async function deleteCollection(ref) {
  const snap = await ref.get();
  for (const doc of snap.docs) await doc.ref.delete();
  return snap.size || snap.docs.length;
}

async function deleteProjectTree(projectRef) {
  const stages = await projectRef.collection("stages").get();
  let requests = await deleteCollection(projectRef.collection("requests"));
  for (const stage of stages.docs) {
    requests += await deleteCollection(stage.ref.collection("requests"));
    await stage.ref.delete();
  }
  await projectRef.delete();
  return { stages: stages.size || stages.docs.length, requests };
}

async function deleteJobTree(jobRef) {
  const commands = await deleteCollection(jobRef.collection("commands"));
  const stages = await deleteCollection(jobRef.collection("stages"));
  await jobRef.delete();
  return { commands, stages };
}

async function deleteOwnedMatches(db, collection, uid, instructionId) {
  const snap = await db.collection(collection).get();
  let deleted = 0;
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (String(data.ownerUid || "") !== uid) continue;
    const nested = data.instruction && typeof data.instruction === "object"
      ? String(data.instruction.instructionId || "")
      : "";
    if (String(data.instructionId || nested) !== instructionId) continue;
    await doc.ref.delete();
    deleted += 1;
  }
  return deleted;
}

async function finalizeCancelledRun(db, spec, deps = {}) {
  const { uid, operationId: opId, jobId, instructionId, projectId, agentId } = spec;
  const opRef = db.collection(CANCEL_OPERATIONS).doc(opId);
  const opSnap = await opRef.get();
  const existing = opSnap.exists ? (opSnap.data() || {}) : {};
  const wasCompleted = existing.status === "completed";
  if (!wasCompleted) {
    await opRef.set({ status: "finalizing", updatedAt: nowIso() }, { merge: true });
  }

  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const projectRef = db.collection(COL.PROJECTS).doc(projectId);
  const jobSnap = await jobRef.get();
  const projectSnap = await projectRef.get();
  if (jobSnap.exists) {
    const job = jobSnap.data() || {};
    if (String(job.ownerUid || "") !== uid ||
        String(job.instructionId || "") !== instructionId) {
      throw httpError(409, "run_mismatch", "job changed before cancel finalize");
    }
  }

  const assignedAgentId = text(agentId || (jobSnap.exists ? jobSnap.data().assignedAgentId : ""), 128);
  if (assignedAgentId) {
    const agentRef = db.collection(COL.AGENTS).doc(assignedAgentId);
    const agentSnap = await agentRef.get();
    if (agentSnap.exists) {
      const agent = agentSnap.data() || {};
      if (String(agent.ownerUid || "") === uid &&
          String(agent.currentJobId || "") === jobId) {
        await agentRef.set({
          currentJobId: "",
          currentStage: "",
          state: "idle",
          updatedAt: nowIso(),
        }, { merge: true });
      }
    }
  }

  const project = await deleteProjectTree(projectRef);
  const job = await deleteJobTree(jobRef);
  const workInstructions = await deleteOwnedMatches(
    db, "workInstructions", uid, instructionId
  );
  const businessPlans = await deleteOwnedMatches(
    db, "businessPlans", uid, instructionId
  );
  let storageObjects = 0;
  if (typeof deps.deleteArtifacts === "function") {
    storageObjects += await deps.deleteArtifacts(
      `sotong24/artifacts/prod/${instructionId}/`
    );
    storageObjects += await deps.deleteArtifacts(
      `sotong24/artifacts/test/${instructionId}/`
    );
  }

  const completedAt = nowIso();
  const result = {
    state: "completed",
    idempotent: wasCompleted,
    operationId: opId,
    deleted: {
      jobs: jobSnap.exists ? 1 : 0,
      jobCommands: job.commands,
      jobStages: job.stages,
      projects: projectSnap.exists ? 1 : 0,
      projectStages: project.stages,
      projectRequests: project.requests,
      workInstructions,
      businessPlans,
      storageObjects,
    },
  };
  await opRef.set({
    ...result,
    ownerUid: uid,
    jobId,
    instructionId,
    projectId,
    protectedAgentId: PROTECTED_AGENT_ID,
    status: "completed",
    completedAt,
    updatedAt: completedAt,
  }, { merge: true });
  return result;
}

async function handleCancelJob(db, uid, body, deps = {}) {
  const jobId = text(body.jobId, 128);
  const instructionId = text(body.instructionId, 128);
  const projectId = text(body.projectId || instructionId, 128);
  if (!jobId || !instructionId || !projectId) {
    throw httpError(400, "invalid_payload", "jobId/instructionId/projectId required");
  }
  if (projectId !== instructionId) {
    throw httpError(409, "run_mismatch", "projectId/instructionId mismatch");
  }

  const opId = operationId(uid, jobId, instructionId);
  const opRef = db.collection(CANCEL_OPERATIONS).doc(opId);
  const opSnap = await opRef.get();
  if (opSnap.exists) {
    const op = opSnap.data() || {};
    if (op.ownerUid !== uid || op.jobId !== jobId ||
        op.instructionId !== instructionId || op.projectId !== projectId) {
      throw httpError(409, "run_mismatch", "cancel operation mismatch");
    }
    if (op.status === "completed") {
      return finalizeCancelledRun(db, {
        uid,
        operationId: opId,
        jobId,
        instructionId,
        projectId,
        agentId: op.agentId,
      }, deps);
    }
  }

  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const projectRef = db.collection(COL.PROJECTS).doc(projectId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) throw httpError(404, "not_found", "job_missing");
  const job = jobSnap.data() || {};
  if (String(job.ownerUid || "") !== uid) {
    throw httpError(403, "forbidden", "job_owner_mismatch");
  }
  if (String(job.instructionId || "") !== instructionId) {
    throw httpError(409, "run_mismatch", "job_instruction_mismatch");
  }
  const projectSnap = await projectRef.get();
  if (!projectSnap.exists) throw httpError(404, "not_found", "project_missing");
  const project = projectSnap.data() || {};
  if (project.ownerUid && String(project.ownerUid) !== uid) {
    throw httpError(403, "forbidden", "project_owner_mismatch");
  }

  const requestId = `cancel_${opId.slice("cancel_".length)}`;
  const requestRef = projectRef.collection("requests").doc(requestId);
  const requestSnap = await requestRef.get();
  if (requestSnap.exists) {
    const request = requestSnap.data() || {};
    if (request.workflowApplied === true && request.processed === true) {
      return finalizeCancelledRun(db, {
        uid,
        operationId: opId,
        jobId,
        instructionId,
        projectId,
        agentId: job.assignedAgentId,
      }, deps);
    }
  }

  const ts = nowIso();
  await opRef.set({
    operationId: opId,
    ownerUid: uid,
    jobId,
    instructionId,
    projectId,
    agentId: String(job.assignedAgentId || ""),
    requestId,
    status: "requested",
    createdAt: opSnap.exists ? (opSnap.data().createdAt || ts) : ts,
    updatedAt: ts,
  }, { merge: true });
  await requestRef.set({
    requestId,
    cancelOperationId: opId,
    ownerUid: uid,
    jobId,
    projectId,
    stageId: String(project.currentStageId || project.currentStage || job.currentStage || ""),
    requestType: "cancel",
    status: "pending",
    message: text(body.message || "사용자 작업 취소", 500),
    processed: false,
    workflowApplied: false,
    createdAt: requestSnap.exists ? (requestSnap.data().createdAt || ts) : ts,
    updatedAt: ts,
  }, { merge: true });
  await jobRef.set({ cancelRequestedAt: ts, cancelOperationId: opId, updatedAt: ts }, { merge: true });
  await projectRef.set({ cancelRequestedAt: ts, cancelOperationId: opId, updatedAt: ts }, { merge: true });
  return { state: "cancel_requested", idempotent: requestSnap.exists, operationId: opId, requestId };
}

async function finalizeCancelRequestEvent(db, event, deps = {}) {
  const after = event.data && event.data.after ? event.data.after : event.data;
  if (!after || !after.exists) return null;
  const request = after.data() || {};
  if (request.requestType !== "cancel" || request.workflowApplied !== true ||
      request.processed !== true) return null;
  const opId = text(request.cancelOperationId, 128);
  if (!opId) return null;
  const opSnap = await db.collection(CANCEL_OPERATIONS).doc(opId).get();
  if (!opSnap.exists) return null;
  const op = opSnap.data() || {};
  return finalizeCancelledRun(db, {
    uid: op.ownerUid,
    operationId: opId,
    jobId: op.jobId,
    instructionId: op.instructionId,
    projectId: op.projectId,
    agentId: op.agentId,
  }, deps);
}

module.exports = {
  CANCEL_OPERATIONS,
  PROTECTED_AGENT_ID,
  operationId,
  isRunCancellationTombstoned,
  handleCancelJob,
  finalizeCancelledRun,
  finalizeCancelRequestEvent,
};
