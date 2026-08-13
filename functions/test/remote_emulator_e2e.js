"use strict";

/**
 * Real Firebase Emulator Suite E2E for Remote Agent API V1.
 * Run via:
 *   firebase emulators:exec --only auth,firestore,functions --project sotongware-control "node functions/test/remote_emulator_e2e.js"
 *
 * Never prints pairingCode / agentToken / idToken.
 */

const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const PROJECT = process.env.GCLOUD_PROJECT || "sotongware-control";
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const FS_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const FN_BASE =
  process.env.REMOTE_API_BASE ||
  `http://127.0.0.1:5001/${PROJECT}/us-central1/api`;

const results = [];
function pass(name) {
  results.push({ name, ok: true });
  console.log(`PASS  ${name}`);
}
function fail(name, err) {
  results.push({ name, ok: false, err: String(err && err.message ? err.message : err) });
  console.error(`FAIL  ${name}: ${err && err.message ? err.message : err}`);
}

async function httpJson(url, { method = "POST", headers = {}, body } = {}) {
  const res = await fetch(url, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  const text = await res.text();
  try {
    json = JSON.parse(text || "null");
  } catch (_) {
    json = { _raw: text.slice(0, 200) };
  }
  return { status: res.status, json };
}

async function signUp(email, password) {
  const url = `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`;
  const res = await httpJson(url, {
    body: { email, password, returnSecureToken: true },
  });
  if (res.status !== 200 || !res.json.idToken) {
    throw new Error(`signUp failed status=${res.status}`);
  }
  return { uid: res.json.localId, idToken: res.json.idToken };
}

function apiUrl(path) {
  const p = path.startsWith("/") ? path : `/${path}`;
  return `${FN_BASE.replace(/\/$/, "")}${p}`;
}

async function control(idToken, path, body = {}) {
  return httpJson(apiUrl(path), {
    headers: { Authorization: `Bearer ${idToken}` },
    body,
  });
}

async function agent(token, path, body = {}) {
  return httpJson(apiUrl(path), {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body,
  });
}

async function fsGet(path, idToken) {
  const url = `http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/${path}`;
  const headers = idToken ? { Authorization: `Bearer ${idToken}` } : {};
  const res = await fetch(url, { headers });
  let json = null;
  try {
    json = JSON.parse(await res.text());
  } catch (_) {}
  return { status: res.status, json };
}

async function fsCreate(path, idToken, fields) {
  // POST to parent with documentId
  const parts = path.split("/");
  const docId = parts.pop();
  const collection = parts.join("/");
  const url = `http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/${collection}?documentId=${encodeURIComponent(docId)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ fields }),
  });
  return { status: res.status, text: await res.text() };
}

async function main() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    console.error("FIRESTORE_EMULATOR_HOST not set — run under firebase emulators:exec");
    process.exit(2);
  }
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT });
  }
  const db = admin.firestore();

  console.log("=== Remote Emulator E2E ===");
  console.log(`project=${PROJECT}`);
  console.log(`fnBase=${FN_BASE}`);
  console.log(`auth=${AUTH_HOST} firestore=${FS_HOST}`);

  // 1. Emulator reachability
  try {
    const health = await httpJson(apiUrl("/api/agent/enroll"), {
      method: "GET",
    });
    assert.equal(health.status, 405);
    pass("1 emulator api up (405 on GET)");
  } catch (e) {
    fail("1 emulator api up", e);
    console.error("Aborting — Functions emulator not reachable");
    process.exit(1);
  }

  const userA = await signUp(`e2e_a_${Date.now()}@test.local`, "Password1!");
  const userB = await signUp(`e2e_b_${Date.now()}@test.local`, "Password1!");
  pass("auth emulator signUp (2 users)");

  let pairingCode;
  let agentId;
  let agentToken;
  let jobId;
  let commandId;

  // 2-3 create-pairing + enroll
  try {
    const pair = await control(userA.idToken, "/api/control/create-pairing", {});
    assert.equal(pair.status, 200);
    assert.equal(pair.json.ok, true);
    assert.ok(pair.json.pairingCode);
    assert.ok(pair.json.sessionId);
    pairingCode = pair.json.pairingCode;
    pass("2 create-pairing");

    const enroll = await agent(null, "/api/agent/enroll", {
      pairingCode,
      deviceName: "E2E-PC",
      appVersion: "Sotong24Work/2.0",
      protocolVersion: "1.0",
    });
    assert.equal(enroll.status, 200);
    assert.ok(enroll.json.agentId);
    assert.ok(enroll.json.agentToken);
    agentId = enroll.json.agentId;
    agentToken = enroll.json.agentToken;
    pass("3 agent enroll");
  } catch (e) {
    fail("2-3 pairing/enroll", e);
  }

  // 4 Bearer auth
  try {
    const noTok = await agent(null, "/api/agent/heartbeat", {
      agentId,
      state: "idle",
      protocolVersion: "1.0",
    });
    assert.equal(noTok.status, 401);
    pass("4 missing bearer → 401");

    const badTok = await agent("not-a-real-token", "/api/agent/heartbeat", {
      agentId,
      state: "idle",
      protocolVersion: "1.0",
    });
    assert.equal(badTok.status, 401);
    pass("5 wrong agent token → 401");
  } catch (e) {
    fail("4-5 auth", e);
  }

  // 6 heartbeat
  try {
    const hb = await agent(agentToken, "/api/agent/heartbeat", {
      agentId,
      state: "idle",
      deviceName: "E2E-PC",
      appVersion: "2.0",
      protocolVersion: "1.0",
      currentJobId: "",
      currentStage: "",
    });
    assert.equal(hb.status, 200);
    const snap = await db.collection("agents").doc(agentId).get();
    assert.ok(snap.exists);
    assert.ok(snap.data().lastHeartbeatAt);
    assert.equal(snap.data().state, "idle");
    pass("6 heartbeat + lastHeartbeatAt");
  } catch (e) {
    fail("6 heartbeat", e);
  }

  // 7-11 create-job / start-job / pull / claim / claim txn
  try {
    const job = await control(userA.idToken, "/api/control/create-job", {
      title: "E2E Test Job",
      type: "ebook",
      assignedAgentId: agentId,
      totalStages: 3,
    });
    assert.equal(job.status, 200);
    jobId = job.json.jobId;
    pass("7 create-job");

    const start = await control(userA.idToken, "/api/control/start-job", {
      jobId,
      payload: {
        schemaVersion: "1.0",
        title: "E2E WI",
        productType: "ebook",
      },
    });
    assert.equal(start.status, 200);
    commandId = start.json.commandId;
    const cmdSnap = await db
      .collection("jobs")
      .doc(jobId)
      .collection("commands")
      .doc(commandId)
      .get();
    assert.equal(cmdSnap.data().status, "queued");
    pass("8 start-job + queued command");

    const pull = await agent(agentToken, "/api/agent/pull", {
      agentId,
      protocolVersion: "1.0",
      limit: 5,
    });
    assert.equal(pull.status, 200);
    assert.ok(Array.isArray(pull.json.commands));
    assert.ok(pull.json.commands.length >= 1);
    assert.equal(pull.json.commands[0].type, "START_JOB");
    pass("9 agent pull (+ collection group index)");

    const claim = await agent(agentToken, "/api/agent/claim", {
      agentId,
      commandId,
      jobId,
      protocolVersion: "1.0",
    });
    assert.equal(claim.status, 200);
    const after = await db
      .collection("jobs")
      .doc(jobId)
      .collection("commands")
      .doc(commandId)
      .get();
    assert.equal(after.data().status, "claimed");
    pass("10 claim transaction");

    const dup = await agent(agentToken, "/api/agent/claim", {
      agentId,
      commandId,
      jobId,
      protocolVersion: "1.0",
    });
    assert.equal(dup.status, 200);
    assert.equal(dup.json.alreadyClaimed, true);
    pass("11 duplicate claim blocked (alreadyClaimed)");
  } catch (e) {
    fail("7-11 job lifecycle", e);
  }

  // 12 complete
  try {
    const done = await agent(agentToken, "/api/agent/complete", {
      agentId,
      commandId,
      jobId,
      protocolVersion: "1.0",
      result: "inbox_delivered",
    });
    assert.equal(done.status, 200);
    const after = await db
      .collection("jobs")
      .doc(jobId)
      .collection("commands")
      .doc(commandId)
      .get();
    assert.equal(after.data().status, "completed");
    pass("12 complete");
  } catch (e) {
    fail("12 complete", e);
  }

  // 13 fail path (new command)
  try {
    const start2 = await control(userA.idToken, "/api/control/start-job", {
      jobId,
      payload: { schemaVersion: "1.0", title: "fail-path" },
      idempotencyKey: `fail-${Date.now()}`,
    });
    assert.equal(start2.status, 200);
    const cid2 = start2.json.commandId;
    await agent(agentToken, "/api/agent/claim", {
      agentId,
      commandId: cid2,
      jobId,
      protocolVersion: "1.0",
    });
    const failed = await agent(agentToken, "/api/agent/fail", {
      agentId,
      commandId: cid2,
      jobId,
      protocolVersion: "1.0",
      code: "test_fail",
      message: "intentional",
    });
    assert.equal(failed.status, 200);
    const snap = await db
      .collection("jobs")
      .doc(jobId)
      .collection("commands")
      .doc(cid2)
      .get();
    assert.equal(snap.data().status, "failed");
    pass("13 fail");
  } catch (e) {
    fail("13 fail", e);
  }

  // 14-16 report-*
  try {
    const rs = await agent(agentToken, "/api/agent/report-state", {
      agentId,
      state: "running",
      protocolVersion: "1.0",
    });
    assert.equal(rs.status, 200);
    pass("14 report-state");

    const rj = await agent(agentToken, "/api/agent/report-job", {
      agentId,
      jobId,
      status: "running",
      protocolVersion: "1.0",
    });
    assert.equal(rj.status, 200);
    pass("15 report-job");

    const rstage = await agent(agentToken, "/api/agent/report-stage", {
      agentId,
      jobId,
      stageId: "stage_1",
      status: "running",
      protocolVersion: "1.0",
    });
    assert.equal(rstage.status, 200);
    pass("16 report-stage");

    const rerr = await agent(agentToken, "/api/agent/report-error", {
      agentId,
      jobId,
      code: "e2e_error",
      message: "test",
      protocolVersion: "1.0",
    });
    assert.equal(rerr.status, 200);
    pass("17 report-error");
  } catch (e) {
    fail("14-17 reports", e);
  }

  // 18 other uid ownership
  try {
    const other = await control(userB.idToken, "/api/control/start-job", {
      jobId,
      payload: {},
    });
    assert.ok(other.status === 403 || other.status === 404 || other.json.ok === false);
    pass("18 other uid ownership blocked");
  } catch (e) {
    fail("18 ownership", e);
  }

  // 19 disabled agent
  try {
    await db.collection("agents").doc(agentId).update({ enabled: false });
    const blocked = await agent(agentToken, "/api/agent/heartbeat", {
      agentId,
      state: "idle",
      protocolVersion: "1.0",
    });
    assert.equal(blocked.status, 403);
    await db.collection("agents").doc(agentId).update({ enabled: true });
    pass("19 disabled agent blocked");
  } catch (e) {
    fail("19 disabled", e);
  }

  // 20-22 Firestore Security Rules
  try {
    const readOwn = await fsGet(`agents/${agentId}`, userA.idToken);
    assert.ok(readOwn.status === 200, `owner read status=${readOwn.status}`);
    pass("20 rules: owner can read agent");

    const readOther = await fsGet(`agents/${agentId}`, userB.idToken);
    assert.ok(
      readOther.status === 403 || readOther.status === 401,
      `other read status=${readOther.status}`
    );
    pass("21 rules: other uid cannot read agent");

    const writeAttempt = await fsCreate(
      `agents/hack_${Date.now()}`,
      userA.idToken,
      {
        ownerUid: { stringValue: userA.uid },
        enabled: { booleanValue: true },
      }
    );
    assert.ok(
      writeAttempt.status === 403 || writeAttempt.status === 401,
      `client write status=${writeAttempt.status}`
    );
    pass("22 rules: client write agents denied");

    const tokWrite = await fsCreate(
      `agentTokens/fakehash`,
      userA.idToken,
      { agentId: { stringValue: "x" } }
    );
    assert.ok(tokWrite.status === 403 || tokWrite.status === 401);
    pass("23 rules: agentTokens client denied");

    const noAuth = await fsGet(`agents/${agentId}`, null);
    assert.ok(noAuth.status === 403 || noAuth.status === 401);
    pass("24 rules: unauthenticated denied");
  } catch (e) {
    fail("20-24 security rules", e);
  }

  // 25 404 route
  try {
    const missing = await control(userA.idToken, "/api/control/no-such-route", {});
    assert.equal(missing.status, 404);
    pass("25 unknown route → 404");
  } catch (e) {
    fail("25 404", e);
  }

  // 26 Control without token
  try {
    const bare = await httpJson(apiUrl("/api/control/create-pairing"), {
      body: {},
    });
    assert.equal(bare.status, 401);
    pass("26 control without token → 401");
  } catch (e) {
    fail("26 control auth", e);
  }

  const failed = results.filter((r) => !r.ok);
  console.log("=== SUMMARY ===");
  console.log(`passed=${results.filter((r) => r.ok).length} failed=${failed.length}`);
  if (failed.length) {
    for (const f of failed) console.error(` - ${f.name}: ${f.err}`);
    process.exit(1);
  }
  console.log("ALL EMULATOR E2E CHECKS PASSED");
}

main().catch((err) => {
  console.error("fatal:", err && err.message ? err.message : err);
  process.exit(1);
});
