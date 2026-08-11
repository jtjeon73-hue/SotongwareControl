"use strict";

const crypto = require("crypto");

/**
 * PC → Relay 인증.
 * - service account private key를 PC에 두지 않음
 * - Shared relay token (Firebase Secret: SOTONG24_RELAY_SECRET)
 * - Authorization: Bearer <token> 또는 X-Sotong24-Relay-Token
 * - 소스/Git에 secret 금지 · 미설정 시 fail-closed
 */
function extractToken(req) {
  const header = req.get("authorization") || req.get("Authorization") || "";
  if (header.toLowerCase().startsWith("bearer ")) {
    return header.slice(7).trim();
  }
  const alt = req.get("x-sotong24-relay-token") || "";
  return String(alt).trim();
}

function timingSafeEqualString(a, b) {
  const aa = Buffer.from(String(a), "utf8");
  const bb = Buffer.from(String(b), "utf8");
  if (aa.length !== bb.length) {
    // 길이 누출 완화: 더미 비교
    crypto.timingSafeEqual(aa, aa);
    return false;
  }
  return crypto.timingSafeEqual(aa, bb);
}

function assertRelayAuth(req, expectedSecret) {
  const secret = String(expectedSecret || "").trim();
  if (!secret) {
    const err = new Error("relay_secret_not_configured");
    err.code = "failed-precondition";
    err.httpStatus = 503;
    throw err;
  }
  const token = extractToken(req);
  if (!token) {
    const err = new Error("missing_auth");
    err.code = "unauthenticated";
    err.httpStatus = 401;
    throw err;
  }
  if (!timingSafeEqualString(token, secret)) {
    const err = new Error("invalid_auth");
    err.code = "permission-denied";
    err.httpStatus = 403;
    throw err;
  }
}

module.exports = {
  extractToken,
  timingSafeEqualString,
  assertRelayAuth,
};
