"use strict";

const { COL, PROTOCOL_VERSION, MAX_BODY_BYTES } = require("./constants");
const { sha256Hex } = require("./crypto_util");
const { httpError } = require("./http");

function readJsonBody(req) {
  const raw = req.rawBody
    ? req.rawBody
    : Buffer.from(JSON.stringify(req.body || {}));
  if (raw.length > MAX_BODY_BYTES) {
    throw httpError(413, "payload_too_large");
  }
  if (req.body && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
    return req.body;
  }
  try {
    return JSON.parse(raw.toString("utf8") || "{}");
  } catch (_) {
    throw httpError(400, "bad_json");
  }
}

function extractBearer(req) {
  const header = req.get("authorization") || req.get("Authorization") || "";
  if (!header.toLowerCase().startsWith("bearer ")) return "";
  return header.slice(7).trim();
}

function assertProtocolVersion(body) {
  const v = String(body.protocolVersion || "").trim();
  if (!v) return PROTOCOL_VERSION;
  if (v !== PROTOCOL_VERSION) {
    throw httpError(400, "protocol_version_incompatible", `expected ${PROTOCOL_VERSION}`);
  }
  return v;
}

/**
 * Resolve agent from Bearer token (hash lookup). Never log token.
 */
async function authenticateAgent(db, req, body) {
  const token = extractBearer(req);
  if (!token) throw httpError(401, "unauthorized", "missing_auth");

  const tokenHash = sha256Hex(token);
  const tokenSnap = await db.collection(COL.AGENT_TOKENS).doc(tokenHash).get();
  if (!tokenSnap.exists) throw httpError(401, "unauthorized", "invalid_token");

  const agentId = String(tokenSnap.data().agentId || "");
  if (!agentId) throw httpError(401, "unauthorized", "invalid_token");

  const agentRef = db.collection(COL.AGENTS).doc(agentId);
  const agentSnap = await agentRef.get();
  if (!agentSnap.exists) throw httpError(401, "unauthorized", "agent_missing");

  const agent = agentSnap.data() || {};
  if (agent.enabled === false) {
    throw httpError(403, "forbidden", "agent_disabled");
  }

  const bodyAgentId = body && body.agentId != null ? String(body.agentId).trim() : "";
  if (bodyAgentId && bodyAgentId !== agentId) {
    throw httpError(403, "forbidden", "agent_mismatch");
  }

  assertProtocolVersion(body || {});

  return { agentId, agent, agentRef };
}

/**
 * Firebase Auth ID token for Control APIs.
 * deps.verifyIdToken optional for tests.
 */
async function authenticateControl(req, deps) {
  const token = extractBearer(req);
  if (!token) throw httpError(401, "unauthorized", "missing_auth");

  const verify =
    deps.verifyIdToken ||
    (async (t) => {
      const admin = require("firebase-admin");
      return admin.auth().verifyIdToken(t);
    });

  try {
    const decoded = await verify(token);
    if (!decoded || !decoded.uid) throw httpError(401, "unauthorized", "invalid_id_token");
    return { uid: decoded.uid, email: decoded.email || "" };
  } catch (err) {
    if (err.httpStatus) throw err;
    throw httpError(401, "unauthorized", "invalid_id_token");
  }
}

module.exports = {
  readJsonBody,
  extractBearer,
  assertProtocolVersion,
  authenticateAgent,
  authenticateControl,
};
