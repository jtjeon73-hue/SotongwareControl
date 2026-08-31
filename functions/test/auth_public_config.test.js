"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
  handleAuthPublicConfig,
  resolveControlAuthPublicConfig,
} = require("../remote/auth_public_config");

function mockRes() {
  return {
    statusCode: 0,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

describe("auth public config", () => {
  it("returns configured admin mapping on GET", () => {
    const res = mockRes();
    handleAuthPublicConfig({ method: "GET" }, res);
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.configured, true);
    assert.equal(res.body.displayAdminId, "sotongware");
    assert.ok(res.body.adminAuthEmail.includes("@"));
    assert.ok(res.body.adminUid.length > 10);
  });

  it("rejects non-GET", () => {
    const res = mockRes();
    handleAuthPublicConfig({ method: "POST" }, res);
    assert.equal(res.statusCode, 405);
  });

  it("resolveControlAuthPublicConfig matches firestore admin identity", () => {
    const cfg = resolveControlAuthPublicConfig();
    assert.equal(cfg.adminAuthEmail, "sotongware@naver.com");
    assert.equal(cfg.adminUid, "YrJNhBlxSeck5qZi5NgHWrx1CjE3");
  });
});
