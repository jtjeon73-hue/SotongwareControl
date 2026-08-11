"use strict";

const { assertRelayAuth } = require("./auth");
const {
  pickProjectAllowlist,
  pickStageAllowlist,
  assertOperations,
  reject,
} = require("./validate");
const { upsertProject, upsertStages } = require("./writer");
const { createRateLimiter } = require("./rate_limit");

const MAX_BODY_BYTES = 100 * 1024;
const rateLimiter = createRateLimiter({ windowMs: 60_000, max: 30 });

function nowIso() {
  return new Date().toISOString();
}

function safeLog(event) {
  // secret / Authorization / 원고 본문 금지
  const line = {
    ts: nowIso(),
    op: event.op || null,
    projectId: event.projectId || null,
    result: event.result || null,
    code: event.code || null,
  };
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

/**
 * 핵심 처리 — 단위 테스트에서 db/secret 주입.
 */
async function handleRelayRequest(req, res, deps) {
  const { getSecret, db } = deps;
  const started = Date.now();

  try {
    if (req.method !== "POST") {
      res.status(405).json({ ok: false, code: "method_not_allowed" });
      return;
    }

    assertRelayAuth(req, getSecret());

    const body = readJsonBody(req);
    const operation = assertOperations(String(body.operation || "").trim());
    const serverNowIso = nowIso();

    // rate limit key: projectId (없으면 ip)
    const tentativeId =
      (body.project && body.project.projectId) ||
      body.projectId ||
      req.ip ||
      "unknown";
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

    let projectInput = body.project;
    if (!projectInput && body.projectId) {
      projectInput = { ...body };
      delete projectInput.operation;
      delete projectInput.stages;
      delete projectInput.stage;
    }

    if (operation === "heartbeat") {
      // heartbeat: projectId + pcStatus 최소
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
      // heartbeat는 progress/status 강제하지 않음 — allowlist가 넣은 서버시간만 merge
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
    safeLog({
      op: null,
      projectId: null,
      result: "error",
      code: String(code),
    });
    res.status(status).json({
      ok: false,
      code,
      message: status >= 500 ? "internal_error" : String(err.message || code),
    });
  }
}

module.exports = {
  handleRelayRequest,
  rateLimiter,
  MAX_BODY_BYTES,
};
