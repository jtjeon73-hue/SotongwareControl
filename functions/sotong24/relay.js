"use strict";

const { assertRelayAuth } = require("./auth");
const {
  pickProjectAllowlist,
  pickStageAllowlist,
  pickRequestAllowlist,
  parseRequestPollInput,
  parseRequestAppliedInput,
  assertProjectStageAlignment,
  assertOperations,
  sortRequestsNewestFirst,
  reject,
  REQUEST_POLL_MAX_READ,
} = require("./validate");
const { upsertProject, upsertStages, markRequestWorkflowApplied } = require("./writer");
const { getProjectDoc, listRequestDocs } = require("./reader");
const { createRateLimiter } = require("./rate_limit");
const {
  parseArtifactUploadInit,
  parseArtifactUploadComplete,
  createUploadGrant,
  finalizeUpload,
  scrubErrorText,
} = require("./artifact");

const MAX_BODY_BYTES = 100 * 1024;
const rateLimiter = createRateLimiter({ windowMs: 60_000, max: 30 });

function nowIso() {
  return new Date().toISOString();
}

function safeLog(event) {
  // secret / Authorization / signed URL query / 원고 본문 금지
  const line = {
    ts: nowIso(),
    op: event.op || null,
    projectId: event.projectId || null,
    result: event.result || null,
    code: event.code || null,
  };
  if (event.storagePath) line.storagePath = event.storagePath;
  if (event.detail) line.detail = event.detail;
  if (event.stageId) line.stageId = event.stageId;
  if (event.revision !== undefined && event.revision !== null) {
    line.revision = event.revision;
  }
  if (event.fileName) line.fileName = event.fileName;
  if (event.safeError) line.safeError = event.safeError;
  console.log(JSON.stringify(line));
}

function readJsonBody(req) {
  const raw = req.rawBody
    ? req.rawBody
    : Buffer.from(JSON.stringify(req.body || {}));
  if (raw.length > MAX_BODY_BYTES) {
    reject("invalid_argument", "payload_too_large", 413);
  }
  if (req.body && typeof req.body === "object") return req.body;
  try {
    return JSON.parse(raw.toString("utf8") || "{}");
  } catch (_) {
    reject("invalid_argument", "invalid_json");
  }
}

function requireArtifactDeps(deps) {
  if (!deps || typeof deps.signUrl !== "function") {
    reject("failed-precondition", "storage_signer_unavailable", 503);
  }
  return deps;
}

/**
 * 핵심 처리 — 단위 테스트에서 db/secret/signUrl 주입.
 */
async function handleRelayRequest(req, res, deps) {
  const { getSecret, db } = deps;
  const started = Date.now();
  let logOp = null;
  let logProjectId = null;

  try {
    if (req.method !== "POST") {
      res.status(405).json({ ok: false, code: "method_not_allowed" });
      return;
    }

    assertRelayAuth(req, getSecret());

    const body = readJsonBody(req);
    const operation = assertOperations(String(body.operation || "").trim());
    logOp = operation;
    const serverNowIso = nowIso();

    const tentativeId =
      (body.project && body.project.projectId) ||
      body.projectId ||
      body.instructionId ||
      req.ip ||
      "unknown";
    logProjectId = String(tentativeId);
    const rl = rateLimiter.check(String(tentativeId));
    if (!rl.ok) {
      safeLog({
        op: operation,
        projectId: tentativeId,
        result: "rate_limited",
        code: "resource_exhausted",
      });
      res.status(429).json({ ok: false, code: "resource_exhausted" });
      return;
    }

    if (operation === "artifact_upload_init") {
      const artifactDeps = requireArtifactDeps(deps);
      const parsed = parseArtifactUploadInit(body);
      const projectData = await getProjectDoc(db, parsed.instructionId);
      if (projectData && projectData.isDemo === true) {
        reject("permission-denied", "demo_project_blocked", 403);
      }
      const grant = await createUploadGrant(parsed, artifactDeps);
      safeLog({
        op: operation,
        projectId: parsed.instructionId,
        result: "ok",
        storagePath: parsed.storagePath,
      });
      res.status(200).json({
        ...grant,
        serverReceivedAt: serverNowIso,
        elapsedMs: Date.now() - started,
      });
      return;
    }

    if (operation === "artifact_upload_complete") {
      const artifactDeps = requireArtifactDeps(deps);
      const parsed = parseArtifactUploadComplete(body);
      const projectData = await getProjectDoc(db, parsed.instructionId);
      if (projectData && projectData.isDemo === true) {
        reject("permission-denied", "demo_project_blocked", 403);
      }
      const done = await finalizeUpload(parsed, artifactDeps);
      safeLog({
        op: operation,
        projectId: parsed.instructionId,
        result: "ok",
        storagePath: parsed.storagePath,
      });
      res.status(200).json({
        ...done,
        serverReceivedAt: serverNowIso,
        elapsedMs: Date.now() - started,
      });
      return;
    }

    if (operation === "request_poll") {
      const poll = parseRequestPollInput(body);
      const projectData = await getProjectDoc(db, poll.projectId);
      if (!projectData) {
        reject("not-found", "project_not_found", 404);
      }
      if (projectData.isDemo === true) {
        reject("permission-denied", "demo_project_blocked", 403);
      }
      assertProjectStageAlignment(
        projectData,
        poll.currentStageId,
        poll.productType
      );

      const rawDocs = await listRequestDocs(db, poll.projectId, {
        maxRead: REQUEST_POLL_MAX_READ,
      });
      const requests = rawDocs
        .map((row) =>
          pickRequestAllowlist(row.data, {
            docId: row.id,
            expectedProjectId: poll.projectId,
            currentStageId: poll.currentStageId,
          })
        )
        .filter(Boolean)
        .sort(sortRequestsNewestFirst)
        .slice(0, poll.limit);

      safeLog({
        op: operation,
        projectId: poll.projectId,
        result: "ok",
      });
      res.status(200).json({
        ok: true,
        operation,
        projectId: poll.projectId,
        currentStageId: poll.currentStageId,
        requests,
        serverReceivedAt: serverNowIso,
        elapsedMs: Date.now() - started,
      });
      return;
    }

    if (operation === "request_applied") {
      const receipt = parseRequestAppliedInput(body);
      const result = await markRequestWorkflowApplied(db, receipt, serverNowIso);
      safeLog({
        op: operation,
        projectId: receipt.projectId,
        stageId: receipt.completedStageId,
        result: result.idempotent ? "idempotent" : "ok",
      });
      res.status(200).json({
        ok: true,
        operation,
        projectId: receipt.projectId,
        requestId: receipt.requestId,
        workflowApplied: true,
        idempotent: result.idempotent,
        serverReceivedAt: serverNowIso,
      });
      return;
    }

    let projectInput = body.project;
    if (!projectInput && body.projectId) {
      projectInput = { ...body };
      delete projectInput.operation;
      delete projectInput.stages;
      delete projectInput.stage;
      delete projectInput.currentStageId;
      delete projectInput.limit;
    }

    if (operation === "heartbeat") {
      if (!projectInput || !projectInput.projectId) {
        reject("invalid_argument", "project.projectId required");
      }
      const minimal = {
        projectId: projectInput.projectId,
        productType: projectInput.productType || "ebook",
        pcStatus: projectInput.pcStatus || "online",
        lastHeartbeat: projectInput.lastHeartbeat,
        updatedAt: projectInput.updatedAt,
      };
      const project = pickProjectAllowlist(minimal, { serverNowIso });
      const hbDoc = {
        projectId: project.projectId,
        pcStatus: project.pcStatus || "online",
        lastHeartbeat: project.lastHeartbeat,
        updatedAt: project.updatedAt,
        serverReceivedAt: project.serverReceivedAt,
        isDemo: false,
      };
      if (project.clientHeartbeatAt) {
        hbDoc.clientHeartbeatAt = project.clientHeartbeatAt;
      }
      const result = await upsertProject(db, hbDoc);
      safeLog({
        op: operation,
        projectId: project.projectId,
        result: "ok",
      });
      res.status(200).json({
        ok: true,
        operation,
        projectId: project.projectId,
        serverReceivedAt: serverNowIso,
        created: result.created,
        elapsedMs: Date.now() - started,
      });
      return;
    }

    if (!projectInput) reject("invalid_argument", "project required");
    const project = pickProjectAllowlist(projectInput, { serverNowIso });

    if (operation === "project_sync") {
      const result = await upsertProject(db, project);
      safeLog({ op: operation, projectId: project.projectId, result: "ok" });
      res.status(200).json({
        ok: true,
        operation,
        projectId: project.projectId,
        serverReceivedAt: serverNowIso,
        created: result.created,
        elapsedMs: Date.now() - started,
      });
      return;
    }

    let stagesRaw = [];
    if (operation === "stage_sync") {
      if (body.stage) stagesRaw = [body.stage];
      else if (Array.isArray(body.stages)) stagesRaw = body.stages;
      else reject("invalid_argument", "stage_or_stages required");
    } else if (operation === "full_sync") {
      if (!Array.isArray(body.stages) || body.stages.length === 0) {
        reject("invalid_argument", "stages required");
      }
      stagesRaw = body.stages;
    }

    if (stagesRaw.length > 32) {
      reject("invalid_argument", "too_many_stages");
    }

    const stages = stagesRaw.map((s) =>
      pickStageAllowlist(s, {
        productType: project.productType,
        serverNowIso,
      })
    );

    const projectResult = await upsertProject(db, project);
    const stageResults = await upsertStages(db, project.projectId, stages);

    safeLog({ op: operation, projectId: project.projectId, result: "ok" });
    res.status(200).json({
      ok: true,
      operation,
      projectId: project.projectId,
      serverReceivedAt: serverNowIso,
      created: projectResult.created,
      stages: stageResults,
      elapsedMs: Date.now() - started,
    });
  } catch (err) {
    const status = err.httpStatus || 500;
    const code = err.code || "internal";
    const line = {
      op: logOp,
      projectId: logProjectId,
      result: "error",
      code: String(code),
    };
    // Artifact failures already emit [ARTIFACT] detail; keep catch log safe.
    if (String(code).startsWith("artifact_")) {
      line.safeError = String(code);
    }
    if (
      logOp === "artifact_upload_init" ||
      logOp === "artifact_upload_complete"
    ) {
      // Safe validation detail for Agent/ops diagnosis (no secrets/URLs).
      line.detail = scrubErrorText(err && err.message).slice(0, 160);
      if (req && req.body && typeof req.body === "object") {
        line.stageId = String(req.body.stageId || "").slice(0, 64) || null;
        line.revision =
          req.body.revision !== undefined ? Number(req.body.revision) : null;
        line.fileName = String(req.body.fileName || "").slice(0, 180) || null;
      }
    }
    safeLog(line);
    const clientMessage =
      status >= 500 && !String(code).startsWith("artifact_")
        ? "internal_error"
        : String(err.message || code);
    res.status(status).json({
      ok: false,
      code,
      message: clientMessage,
    });
  }
}

module.exports = {
  handleRelayRequest,
  rateLimiter,
  MAX_BODY_BYTES,
};
