"use strict";

const {
  authenticateAgent,
  authenticateControl,
  readJsonBody,
} = require("./auth");
const { sendError, sendOk, httpError } = require("./http");
const { safeLog } = require("./log");
const { handleArtifactDownload } = require("./artifact_download");
const { handleArtifactView } = require("./artifact_view");
const {
  handleEnroll,
  handleHeartbeat,
  handlePull,
  handleClaim,
  handleComplete,
  handleFail,
  handleReportState,
  handleReportJob,
  handleReportStage,
  handleReportActivity,
  handleReportError,
  handleCreatePairing,
  handleRegisterNotificationToken,
  handleCreateJob,
  handleStartJob,
  handleDeliverInstruction,
  handleCancelJob,
  validateApproveStageBody,
  validateRequestRevisionBody,
} = require("./handlers");

function normalizePath(req) {
  let p = req.path || req.url || "/";
  if (p.includes("?")) p = p.split("?")[0];
  // Cloud Functions may prefix /api when using hosting rewrite
  if (!p.startsWith("/")) p = `/${p}`;
  return p;
}

/**
 * Single HTTPS entry for Agent + Control APIs.
 * deps: { db, verifyIdToken? }
 */
async function handleApiRequest(req, res, deps) {
  const started = Date.now();
  const path = normalizePath(req);
  let logCtx = { type: path };

  try {
    if (req.method !== "POST") {
      res.status(405).json({ ok: false, error: "method_not_allowed" });
      return;
    }

    const body = readJsonBody(req);
    const db = deps.db;

    if (
      path === "/api/control/artifact-view" ||
      path === "/control/artifact-view"
    ) {
      const { uid } = await authenticateControl(req, deps);
      const out = await handleArtifactView(db, uid, body, deps);
      safeLog({
        type: path,
        status: "ok",
        sizeBytes: out.sizeBytes,
        latencyMs: Date.now() - started,
      });
      res.status(200);
      res.set("Content-Type", "application/pdf");
      res.set("Content-Disposition", 'inline; filename="preview.pdf"');
      res.set("Cache-Control", "private, no-store");
      res.set("X-Content-Type-Options", "nosniff");
      res.send(out.bytes);
      return;
    }

    // --- Agent (public enroll) ---
    if (path === "/api/agent/enroll" || path === "/agent/enroll") {
      const out = await handleEnroll(db, body);
      safeLog({ ...logCtx, type: "enroll", agentId: out.agentId, status: "ok", latencyMs: Date.now() - started });
      sendOk(res, { agentId: out.agentId, agentToken: out.agentToken });
      return;
    }

    const agentRoutes = {
      "/api/agent/heartbeat": handleHeartbeat,
      "/agent/heartbeat": handleHeartbeat,
      "/api/agent/pull": handlePull,
      "/agent/pull": handlePull,
      "/api/agent/claim": handleClaim,
      "/agent/claim": handleClaim,
      "/api/agent/complete": handleComplete,
      "/agent/complete": handleComplete,
      "/api/agent/fail": handleFail,
      "/agent/fail": handleFail,
      "/api/agent/report-state": handleReportState,
      "/agent/report-state": handleReportState,
      "/api/agent/report-job": handleReportJob,
      "/agent/report-job": handleReportJob,
      "/api/agent/report-stage": handleReportStage,
      "/agent/report-stage": handleReportStage,
      "/api/agent/report-activity": handleReportActivity,
      "/agent/report-activity": handleReportActivity,
      "/api/agent/report-error": handleReportError,
      "/agent/report-error": handleReportError,
    };

    if (agentRoutes[path]) {
      const ctx = await authenticateAgent(db, req, body);
      logCtx = { type: path, agentId: ctx.agentId };
      const out = await agentRoutes[path](db, ctx, body);
      safeLog({
        ...logCtx,
        jobId: body.jobId || null,
        commandId: body.commandId || null,
        status: "ok",
        latencyMs: Date.now() - started,
      });
      sendOk(res, out || {});
      return;
    }

    // --- Control (Firebase Auth) ---
    const controlRoutes = {
      "/api/control/create-pairing": async () => {
        const { uid } = await authenticateControl(req, deps);
        logCtx = { type: path, agentId: null };
        return handleCreatePairing(db, uid, body);
      },
      "/api/control/register-notification-token": async () => {
        const { uid } = await authenticateControl(req, deps);
        return handleRegisterNotificationToken(db, uid, body);
      },
      "/api/control/create-job": async () => {
        const { uid } = await authenticateControl(req, deps);
        return handleCreateJob(db, uid, body);
      },
      "/api/control/start-job": async () => {
        const { uid } = await authenticateControl(req, deps);
        return handleStartJob(db, uid, body);
      },
      "/api/control/deliver-instruction": async () => {
        const { uid } = await authenticateControl(req, deps);
        return handleDeliverInstruction(db, uid, body);
      },
      "/api/control/artifact-download": async () => {
        const { uid } = await authenticateControl(req, deps);
        return handleArtifactDownload(db, uid, body, deps);
      },
      "/api/control/approve-stage": async () => {
        await authenticateControl(req, deps);
        validateApproveStageBody(body);
        // Queue command stub — full wire in later phase
        throw httpError(501, "unimplemented", "approve-stage queued in later phase");
      },
      "/api/control/request-revision": async () => {
        await authenticateControl(req, deps);
        validateRequestRevisionBody(body);
        throw httpError(501, "unimplemented", "request-revision queued in later phase");
      },
      "/api/control/pause-job": async () => {
        await authenticateControl(req, deps);
        throw httpError(501, "unimplemented", "pause-job later phase");
      },
      "/api/control/resume-job": async () => {
        await authenticateControl(req, deps);
        throw httpError(501, "unimplemented", "resume-job later phase");
      },
      "/api/control/cancel-job": async () => {
        const { uid } = await authenticateControl(req, deps);
        return handleCancelJob(db, uid, body, deps);
      },
    };

    // also accept without /api prefix
    const alt = path.startsWith("/control/") ? `/api${path}` : null;
    const controlHandler = controlRoutes[path] || (alt && controlRoutes[alt]);
    if (controlHandler) {
      const out = await controlHandler();
      safeLog({ type: path, status: "ok", latencyMs: Date.now() - started });
      sendOk(res, out || {});
      return;
    }

    res.status(404).json({ ok: false, error: "not_found" });
  } catch (err) {
    safeLog({
      ...logCtx,
      status: "error",
      code: err.error || err.code || "error",
      latencyMs: Date.now() - started,
    });
    sendError(res, err);
  }
}

module.exports = { handleApiRequest, normalizePath };
