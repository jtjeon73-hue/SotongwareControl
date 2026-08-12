"use strict";

const crypto = require("crypto");

function sha256Hex(value) {
  return crypto.createHash("sha256").update(String(value), "utf8").digest("hex");
}

function randomToken(bytes = 32) {
  return crypto.randomBytes(bytes).toString("base64url");
}

/** Short pairing code for human entry (no ambiguous chars). */
function randomPairingCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const buf = crypto.randomBytes(8);
  let out = "";
  for (let i = 0; i < 8; i++) {
    out += alphabet[buf[i] % alphabet.length];
  }
  return out;
}

function newId(prefix) {
  return `${prefix}_${crypto.randomBytes(8).toString("hex")}`;
}

function timingSafeEqualHex(a, b) {
  const aa = Buffer.from(String(a), "utf8");
  const bb = Buffer.from(String(b), "utf8");
  if (aa.length !== bb.length) {
    crypto.timingSafeEqual(aa, aa);
    return false;
  }
  return crypto.timingSafeEqual(aa, bb);
}

module.exports = {
  sha256Hex,
  randomToken,
  randomPairingCode,
  newId,
  timingSafeEqualHex,
};
