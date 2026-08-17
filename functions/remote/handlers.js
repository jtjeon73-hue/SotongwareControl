"use strict";

const {
  COL,
  COMMAND_STATUS,
  WORK_STATUS,
  AGENT_STATE,
  PROTOCOL_VERSION,
  PAIRING_TTL_MS,
  PULL_DEFAULT_LIMIT,
  PULL_MAX_LIMIT,
  ONLINE_WITHIN_MS,
  COMMAND_TYPE,
} = require("./constants");
const {
  sha256Hex,
  randomToken,
  randomPairingCode,
  newId,
} = require("./crypto_util");
const { httpError, sendOk } = require("./http");
const { nowIso } = require("./log");
const { assertProtocolVersion } = require("./auth");

const AGENT_STATES = new Set(Object.values(AGENT_STATE));
const WORK_STATUSES = new Set(Object.values(WORK_STATUS));

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

async function handleEnroll(db, body) {
  assertProtocolVersion(body);
  const pairingCode = String(body.pairingCode || "").trim();
  const deviceName = String(body.deviceName || "device").trim().slice(0, 120);
  const appVersion = String(body.appVersion || "").trim().slice(0, 120);
  if (!pairingCode) throw httpError(400, "bad_request", "pairingCode required");

  const codeHash = sha256Hex(pairingCode.toUpperCase());
  // Find unused session by codeHash (scan limited — also store codeHash as doc id optional)
  const q = await db
    .collection(COL.PAIRING)
    .where("codeHash", "==", codeHash)
    .where("used", "==", false)
    .limit(5)
    .get();

  if (q.empty) throw httpError(403, "bad_pairing", "invalid_or_used");

  const now = Date.now();
  let sessionDoc = null;
  for (const doc of q.docs) {
    const data = doc.data() || {};
    const exp = data.expiresAt && data.expiresAt.toMillis
      ? data.expiresAt.toMillis()
      : Date.parse(data.expiresAt || "") || 0;
    if (exp && exp < now) continue;
    sessionDoc = doc;
    break;
  }
  if (!sessionDoc) throw httpError(403, "bad_pairing", "expired");

  const session = sessionDoc.data() || {};
  const ownerUid = String(session.ownerUid || "");
  if (!ownerUid) throw httpError(500, "internal", "pairing_owner_missing");

  const agentId = newId("agent");
  const agentToken = randomToken(32);
  const tokenHash = sha256Hex(agentToken);
  const ts = nowIso();

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(sessionDoc.ref);
    if (!fresh.exists) throw httpError(403, "bad_pairing", "invalid_or_used");
    const d = fresh.data() || {};
    if (d.used === true) throw httpError(403, "bad_pairing", "already_used");
    const exp = d.expiresAt && d.expiresAt.toMillis
      ? d.expiresAt.toMillis()
      : Date.parse(d.expiresAt || "") || 0;
    if (exp && exp < Date.now()) throw httpError(403, "bad_pairing", "expired");

    tx.set(db.collection(COL.AGENTS).doc(agentId), {
      agentId,
      ownerUid,
      deviceName,
      state: AGENT_STATE.IDLE,
      online: false,
      enabled: true,
      lastHeartbeatAt: null,
      appVersion,
      protocolVersion: PROTOCOL_VERSION,
      currentJobId: "",
      currentStage: "",
      tokenHash,
      createdAt: ts,
      updatedAt: ts,
    });
    tx.set(db.collection(COL.AGENT_TOKENS).doc(tokenHash), {
      agentId,
      ownerUid,
      createdAt: ts,
    });
    tx.update(sessionDoc.ref, {
      used: true,
      usedAt: ts,
      agentId,
      updatedAt: ts,
    });
  });

  return { agentId, agentToken };
}

async function handleHeartbeat(db, ctx, body) {
  const state = String(body.state || "").trim();
  if (state && !AGENT_STATES.has(state)) {
    throw httpError(400, "invalid_payload", "state invalid");
  }
  const ts = nowIso();
  const patch = {
    updatedAt: ts,
    lastHeartbeatAt: ts,
    protocolVersion: PROTOCOL_VERSION,
  };
  if (state) patch.state = state;
  if (body.deviceName != null) patch.deviceName = String(body.deviceName).slice(0, 120);
  if (body.appVersion != null) patch.appVersion = String(body.appVersion).slice(0, 120);
  if (body.currentJobId != null) patch.currentJobId = String(body.currentJobId).slice(0, 128);
  if (body.currentStage != null) patch.currentStage = String(body.currentStage).slice(0, 128);
  // online is derived by clients from lastHeartbeatAt — keep mirror hint false here
  patch.online = false;

  await ctx.agentRef.set(patch, { merge: true });
  return {};
}

function commandRef(db, jobId, commandId) {
  return db.collection(COL.JOBS).doc(jobId).collection("commands").doc(commandId);
}

async function handlePull(db, ctx, body) {
  let limit = PULL_DEFAULT_LIMIT;
  if (body.limit != null && body.limit !== "") {
    const n = Number(body.limit);
    if (!Number.isInteger(n) || n < 1 || n > PULL_MAX_LIMIT) {
      throw httpError(400, "invalid_payload", "limit out_of_range");
    }
    limit = n;
  }

  const snap = await db
    .collectionGroup("commands")
    .where("agentId", "==", ctx.agentId)
    .where("status", "==", COMMAND_STATUS.QUEUED)
    .orderBy("createdAt", "asc")
    .limit(limit)
    .get();

  const commands = snap.docs.map((d) => {
    const c = d.data() || {};
    return {
      commandId: c.commandId || d.id,
      idempotencyKey: c.idempotencyKey || "",
      agentId: c.agentId || ctx.agentId,
      jobId: c.jobId || "",
      type: c.type || "",
      createdAt: c.createdAt || "",
      payload: isPlainObject(c.payload) ? c.payload : {},
      status: c.status || COMMAND_STATUS.QUEUED,
    };
  });
  return { commands };
}

async function handleClaim(db, ctx, body) {
  const commandId = String(body.commandId || "").trim();
  const jobId = String(body.jobId || "").trim();
  if (!commandId || !jobId) throw httpError(400, "invalid_payload", "commandId_and_jobId required");

  const ref = commandRef(db, jobId, commandId);
  const ts = nowIso();

  // Firestore requires all transaction reads before any writes.
  const result = await db.runTransaction(async (tx) => {
    const jobRef = db.collection(COL.JOBS).doc(jobId);
    const [snap, jobSnap] = await Promise.all([tx.get(ref), tx.get(jobRef)]);
    if (!snap.exists) throw httpError(404, "not_found", "command_missing");
    const cmd = snap.data() || {};
    if (cmd.agentId !== ctx.agentId) throw httpError(403, "forbidden", "agent_mismatch");

    if (cmd.status === COMMAND_STATUS.CLAIMED) {
      return { alreadyClaimed: true };
    }
    if (cmd.status !== COMMAND_STATUS.QUEUED) {
      throw httpError(409, "not_claimable", `status=${cmd.status}`);
    }

    tx.update(ref, {
      status: COMMAND_STATUS.CLAIMED,
      claimedAt: ts,
      updatedAt: ts,
      attempt: (cmd.attempt || 0) + 1,
    });

    if (jobSnap.exists) {
      tx.update(jobRef, {
        status: WORK_STATUS.CLAIMED,
        updatedAt: ts,
      });
    }
    return { alreadyClaimed: false };
  });

  return result;
}

async function handleComplete(db, ctx, body) {
  const commandId = String(body.commandId || "").trim();
  const jobId = String(body.jobId || "").trim();
  if (!commandId || !jobId) throw httpError(400, "invalid_payload", "commandId_and_jobId required");
  const summary = String(body.summary || "").slice(0, 2000);
  const ts = nowIso();
  const ref = commandRef(db, jobId, commandId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw httpError(404, "not_found", "command_missing");
    const cmd = snap.data() || {};
    if (cmd.agentId !== ctx.agentId) throw httpError(403, "forbidden", "agent_mismatch");
    if (cmd.status === COMMAND_STATUS.COMPLETED) return;
    if (cmd.status !== COMMAND_STATUS.CLAIMED) {
      throw httpError(409, "not_completable", `status=${cmd.status}`);
    }
    tx.update(ref, {
      status: COMMAND_STATUS.COMPLETED,
      completedAt: ts,
      updatedAt: ts,
      summary,
    });
  });
  return {};
}

async function handleFail(db, ctx, body) {
  const commandId = String(body.commandId || "").trim();
  const jobId = String(body.jobId || "").trim();
  if (!commandId || !jobId) throw httpError(400, "invalid_payload", "commandId_and_jobId required");
  const code = String(body.code || "error").slice(0, 120);
  const message = String(body.message || "").slice(0, 500);
  const retryable = body.retryable === true;
  const ts = nowIso();
  const ref = commandRef(db, jobId, commandId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw httpError(404, "not_found", "command_missing");
    const cmd = snap.data() || {};
    if (cmd.agentId !== ctx.agentId) throw httpError(403, "forbidden", "agent_mismatch");
    if (cmd.status === COMMAND_STATUS.FAILED) return;
    if (
      cmd.status !== COMMAND_STATUS.QUEUED &&
      cmd.status !== COMMAND_STATUS.CLAIMED
    ) {
      throw httpError(409, "not_failable", `status=${cmd.status}`);
    }
    tx.update(ref, {
      status: COMMAND_STATUS.FAILED,
      failedAt: ts,
      completedAt: ts,
      updatedAt: ts,
      error: { code, message, retryable },
    });
  });
  return {};
}

async function handleReportState(db, ctx, body) {
  const state = String(body.state || "").trim();
  if (!AGENT_STATES.has(state)) throw httpError(400, "invalid_payload", "state invalid");
  const ts = nowIso();
  await ctx.agentRef.set(
    {
      state,
      updatedAt: ts,
      lastHeartbeatAt: ts,
    },
    { merge: true }
  );
  return {};
}

async function handleReportJob(db, ctx, body) {
  const jobId = String(body.jobId || "").trim();
  const status = String(body.status || "").trim();
  if (!jobId) throw httpError(400, "invalid_payload", "jobId required");
  if (!WORK_STATUSES.has(status)) throw httpError(400, "invalid_payload", "status invalid");

  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const snap = await jobRef.get();
  if (!snap.exists) throw httpError(404, "not_found", "job_missing");
  const job = snap.data() || {};
  if (job.assignedAgentId && job.assignedAgentId !== ctx.agentId) {
    throw httpError(403, "forbidden", "agent_mismatch");
  }
  if (job.ownerUid && ctx.agent.ownerUid && job.ownerUid !== ctx.agent.ownerUid) {
    throw httpError(403, "forbidden", "owner_mismatch");
  }

  const ts = nowIso();
  const patch = {
    status,
    updatedAt: ts,
    assignedAgentId: job.assignedAgentId || ctx.agentId,
    ownerUid: job.ownerUid || ctx.agent.ownerUid,
  };
  if (status === WORK_STATUS.RUNNING && !job.startedAt) patch.startedAt = ts;
  if (status === WORK_STATUS.COMPLETED) patch.completedAt = ts;
  await jobRef.set(patch, { merge: true });
  return {};
}

async function handleReportStage(db, ctx, body) {
  const stageId = String(body.stageId || "").trim();
  const status = String(body.status || "").trim();
  const jobId = String(body.jobId || ctx.agent.currentJobId || "").trim();
  if (!stageId) throw httpError(400, "invalid_payload", "stageId required");
  if (!jobId) throw httpError(400, "invalid_payload", "jobId required");
  if (!WORK_STATUSES.has(status)) throw httpError(400, "invalid_payload", "status invalid");

  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) throw httpError(404, "not_found", "job_missing");
  const job = jobSnap.data() || {};
  if (job.assignedAgentId && job.assignedAgentId !== ctx.agentId) {
    throw httpError(403, "forbidden", "agent_mismatch");
  }

  const ts = nowIso();
  const stageRef = jobRef.collection("stages").doc(stageId);
  const prev = await stageRef.get();
  const patch = {
    stageId,
    status,
    updatedAt: ts,
  };
  if (body.progress != null) patch.progress = Number(body.progress) || 0;
  if (body.summary != null) patch.summary = String(body.summary).slice(0, 2000);
  if (body.stageName != null) patch.stageName = String(body.stageName).slice(0, 120);
  if (body.stageNumber != null) patch.stageNumber = Number(body.stageNumber) || 0;
  if (!prev.exists) patch.startedAt = ts;
  if (status === WORK_STATUS.COMPLETED) patch.completedAt = ts;

  await stageRef.set(patch, { merge: true });
  await jobRef.set({ currentStage: stageId, updatedAt: ts }, { merge: true });
  return {};
}

async function handleReportError(db, ctx, body) {
  const code = String(body.code || "error").slice(0, 120);
  const message = String(body.message || "").slice(0, 500);
  const jobId = String(body.jobId || ctx.agent.currentJobId || "").trim();
  const ts = nowIso();
  const eventId = newId("evt");

  if (jobId) {
    const jobRef = db.collection(COL.JOBS).doc(jobId);
    const jobSnap = await jobRef.get();
    if (jobSnap.exists) {
      const job = jobSnap.data() || {};
      if (job.assignedAgentId && job.assignedAgentId !== ctx.agentId) {
        throw httpError(403, "forbidden", "agent_mismatch");
      }
      await jobRef.collection("events").doc(eventId).set({
        eventId,
        type: "error",
        agentId: ctx.agentId,
        ownerUid: job.ownerUid || ctx.agent.ownerUid || "",
        code,
        message,
        createdAt: ts,
      });
    }
  }

  await ctx.agentRef.set(
    {
      state: AGENT_STATE.ERROR,
      updatedAt: ts,
      lastError: { code, message, at: ts },
    },
    { merge: true }
  );
  return {};
}

/** Control: create pairing session — returns plaintext code once */
async function handleCreatePairing(db, uid, body = {}) {
  const sessionId = newId("pair");
  const pairingCode = randomPairingCode();
  const codeHash = sha256Hex(pairingCode);
  const ts = nowIso();
  const expiresAt = new Date(Date.now() + PAIRING_TTL_MS).toISOString();

  await db.collection(COL.PAIRING).doc(sessionId).set({
    sessionId,
    ownerUid: uid,
    codeHash,
    createdAt: ts,
    expiresAt,
    used: false,
    usedAt: null,
    agentId: null,
    updatedAt: ts,
  });

  return {
    sessionId,
    pairingCode,
    expiresAt,
    ttlSeconds: Math.floor(PAIRING_TTL_MS / 1000),
  };
}

async function handleCreateJob(db, uid, body) {
  const title = String(body.title || "Untitled").trim().slice(0, 200);
  const type = String(body.type || "ebook").trim().slice(0, 64);
  const assignedAgentId = String(body.assignedAgentId || "").trim();
  if (!assignedAgentId) throw httpError(400, "invalid_payload", "assignedAgentId required");

  const agentSnap = await db.collection(COL.AGENTS).doc(assignedAgentId).get();
  if (!agentSnap.exists) throw httpError(404, "not_found", "agent_missing");
  const agent = agentSnap.data() || {};
  if (agent.ownerUid !== uid) throw httpError(403, "forbidden", "agent_owner_mismatch");

  const instructionId = String(body.instructionId || "").trim();
  if (instructionId) {
    const existing = await findJobByInstructionId(db, uid, instructionId);
    if (existing) {
      return { jobId: existing.id, idempotent: true };
    }
  }

  const jobId = newId("job");
  const ts = nowIso();
  const totalStages = Number(body.totalStages) || 18;
  const doc = {
    jobId,
    ownerUid: uid,
    type,
    title,
    status: WORK_STATUS.QUEUED,
    assignedAgentId,
    currentStage: "",
    totalStages,
    progress: 0,
    createdAt: ts,
    startedAt: null,
    completedAt: null,
    updatedAt: ts,
  };
  if (instructionId) doc.instructionId = instructionId;
  await db.collection(COL.JOBS).doc(jobId).set(doc);
  return { jobId, idempotent: false };
}

async function findJobByInstructionId(db, uid, instructionId) {
  const snap = await db
    .collection(COL.JOBS)
    .where("ownerUid", "==", uid)
    .orderBy("updatedAt", "desc")
    .limit(80)
    .get();
  for (const d of snap.docs) {
    const data = d.data() || {};
    if (String(data.instructionId || "").trim() === instructionId) {
      return { id: d.id, data };
    }
  }
  return null;
}

async function findStartCommand(jobRef) {
  const all = await jobRef.collection("commands").get();
  for (const d of all.docs) {
    const data = d.data() || {};
    if (data.type === COMMAND_TYPE.START_JOB && data.commandId) {
      return data;
    }
  }
  return null;
}

async function handleStartJob(db, uid, body) {
  const jobId = String(body.jobId || "").trim();
  if (!jobId) throw httpError(400, "invalid_payload", "jobId required");

  const jobRef = db.collection(COL.JOBS).doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) throw httpError(404, "not_found", "job_missing");
  const job = jobSnap.data() || {};
  if (job.ownerUid !== uid) throw httpError(403, "forbidden", "job_owner_mismatch");
  if (!job.assignedAgentId) throw httpError(400, "invalid_payload", "assignedAgentId missing");

  const existingStart = await findStartCommand(jobRef);
  if (existingStart) {
    return { commandId: existingStart.commandId, jobId, idempotent: true };
  }

  const commandId = newId("cmd");
  const idempotencyKey = String(body.idempotencyKey || `idem_${commandId}`);
  const payload = isPlainObject(body.payload) ? body.payload : {};
  const ts = nowIso();

  const existing = await jobRef
    .collection("commands")
    .where("idempotencyKey", "==", idempotencyKey)
    .limit(1)
    .get();
  if (!existing.empty) {
    const d = existing.docs[0].data();
    return { commandId: d.commandId, jobId, idempotent: true };
  }

  const cmd = {
    commandId,
    jobId,
    agentId: job.assignedAgentId,
    ownerUid: uid,
    type: COMMAND_TYPE.START_JOB,
    status: COMMAND_STATUS.QUEUED,
    idempotencyKey,
    payload,
    createdAt: ts,
    claimedAt: null,
    completedAt: null,
    failedAt: null,
    error: null,
    attempt: 0,
    updatedAt: ts,
  };
  await jobRef.collection("commands").doc(commandId).set(cmd);
  await jobRef.set({ status: WORK_STATUS.QUEUED, updatedAt: ts }, { merge: true });
  return { commandId, jobId, idempotent: false };
}

async function resolveOnlineAgent(db, uid, assignedAgentId) {
  if (assignedAgentId) {
    const snap = await db.collection(COL.AGENTS).doc(assignedAgentId).get();
    if (!snap.exists) throw httpError(404, "not_found", "agent_missing");
    const agent = snap.data() || {};
    if (agent.ownerUid !== uid) throw httpError(403, "forbidden", "agent_owner_mismatch");
    if (agent.enabled === false) {
      throw httpError(409, "agent_offline", "agent disabled");
    }
    if (!isAgentOnline(agent.lastHeartbeatAt)) {
      throw httpError(409, "agent_offline", "agent offline");
    }
    return assignedAgentId;
  }
  const snap = await db.collection(COL.AGENTS).where("ownerUid", "==", uid).get();
  const online = [];
  for (const d of snap.docs) {
    const a = d.data() || {};
    if (a.enabled === false) continue;
    if (!isAgentOnline(a.lastHeartbeatAt)) continue;
    online.push({ id: d.id, agentId: a.agentId || d.id, deviceName: a.deviceName || "" });
  }
  if (online.length === 0) {
    throw httpError(409, "agent_offline", "no online agent");
  }
  const jt = online.find((a) => String(a.deviceName).toUpperCase().includes("JT-JEON"));
  return (jt || online[0]).agentId;
}

async function handleDeliverInstruction(db, uid, body) {
  const instructionId = String(body.instructionId || "").trim();
  if (!instructionId) throw httpError(400, "invalid_payload", "instructionId required");
  const payload = isPlainObject(body.payload) ? body.payload : {};
  const payloadId = String(payload.instructionId || "").trim();
  if (payloadId && payloadId !== instructionId) {
    throw httpError(400, "invalid_payload", "instructionId mismatch");
  }

  const assignedAgentId = await resolveOnlineAgent(
    db,
    uid,
    String(body.assignedAgentId || "").trim()
  );

  const existing = await findJobByInstructionId(db, uid, instructionId);
  const inFlight = new Set([
    WORK_STATUS.CLAIMED,
    WORK_STATUS.RUNNING,
    WORK_STATUS.WAITING_APPROVAL,
    WORK_STATUS.REVISION_REQUESTED,
    WORK_STATUS.REWORKING,
  ]);

  if (existing) {
    const jobId = existing.id;
    const status = existing.data.status;
    const jobRef = db.collection(COL.JOBS).doc(jobId);
    const start = await findStartCommand(jobRef);
    if (start) {
      let outcome = "reused";
      if (inFlight.has(status)) outcome = "reused_in_progress";
      if (status === WORK_STATUS.COMPLETED || status === WORK_STATUS.APPROVED) {
        outcome = "reused_completed";
      }
      return {
        jobId,
        commandId: start.commandId,
        agentId: existing.data.assignedAgentId,
        outcome,
        idempotent: true,
      };
    }
    if (status === WORK_STATUS.COMPLETED || status === WORK_STATUS.APPROVED) {
      throw httpError(409, "already_completed", "job already completed");
    }
    if (inFlight.has(status)) {
      throw httpError(409, "already_in_progress", "job already claimed");
    }
    const started = await handleStartJob(db, uid, {
      jobId,
      payload,
      idempotencyKey: `idem_start_${instructionId}`,
    });
    return {
      jobId,
      commandId: started.commandId,
      agentId: existing.data.assignedAgentId,
      outcome: "command_repaired",
      idempotent: started.idempotent === true,
    };
  }

  const created = await handleCreateJob(db, uid, {
    ...body,
    assignedAgentId,
    instructionId,
  });
  const started = await handleStartJob(db, uid, {
    jobId: created.jobId,
    payload,
    idempotencyKey: `idem_start_${instructionId}`,
  });
  return {
    jobId: created.jobId,
    commandId: started.commandId,
    agentId: assignedAgentId,
    outcome: "created",
    idempotent: false,
  };
}

/** Stubs for approve/revision validators (contract ready) */
function validateApproveStageBody(body) {
  if (!String(body.jobId || "").trim()) throw httpError(400, "invalid_payload", "jobId required");
  if (!String(body.stageId || "").trim()) throw httpError(400, "invalid_payload", "stageId required");
}

function validateRequestRevisionBody(body) {
  validateApproveStageBody(body);
  if (!String(body.message || "").trim()) {
    throw httpError(400, "invalid_payload", "message required");
  }
}

function isAgentOnline(lastHeartbeatAt, now = Date.now()) {
  if (!lastHeartbeatAt) return false;
  const t = typeof lastHeartbeatAt === "string"
    ? Date.parse(lastHeartbeatAt)
    : lastHeartbeatAt.toMillis
      ? lastHeartbeatAt.toMillis()
      : Number(lastHeartbeatAt);
  if (!Number.isFinite(t)) return false;
  return now - t <= ONLINE_WITHIN_MS;
}

module.exports = {
  handleEnroll,
  handleHeartbeat,
  handlePull,
  handleClaim,
  handleComplete,
  handleFail,
  handleReportState,
  handleReportJob,
  handleReportStage,
  handleReportError,
  handleCreatePairing,
  handleCreateJob,
  handleStartJob,
  handleDeliverInstruction,
  validateApproveStageBody,
  validateRequestRevisionBody,
  isAgentOnline,
  sendOk,
};
