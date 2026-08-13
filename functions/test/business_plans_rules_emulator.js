"use strict";

/**
 * Firestore security rules tests for businessPlans.
 * Run:
 *   firebase emulators:exec --only auth,firestore --project sotongware-control "node functions/test/business_plans_rules_emulator.js"
 *
 * Uses Auth + Firestore emulators with user ID tokens (rules enforced).
 * Does not use Admin SDK for rule assertions (Admin bypasses rules).
 */

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const PROJECT = process.env.GCLOUD_PROJECT || "sotongware-control";
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const FS_HOST = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";

const results = [];
function pass(name) {
  results.push({ name, ok: true });
  console.log(`PASS  ${name}`);
}
function fail(name, err) {
  results.push({
    name,
    ok: false,
    err: String(err && err.message ? err.message : err),
  });
  console.error(`FAIL  ${name}: ${err && err.message ? err.message : err}`);
}

async function httpJson(url, { method = "GET", headers = {}, body } = {}) {
  const res = await fetch(url, {
    method,
    headers: {
      ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  const text = await res.text();
  try {
    json = JSON.parse(text || "null");
  } catch (_) {
    json = { _raw: text.slice(0, 300) };
  }
  return { status: res.status, json, text };
}

async function signUp(email, password) {
  const url = `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`;
  const res = await httpJson(url, {
    method: "POST",
    body: { email, password, returnSecureToken: true },
  });
  if (res.status !== 200 || !res.json.idToken) {
    throw new Error(`signUp failed status=${res.status} ${res.text}`);
  }
  return { uid: res.json.localId, idToken: res.json.idToken };
}

/** Production admin identity used by firestore.rules isAdmin(). */
const PROD_ADMIN_UID = "YrJNhBlxSeck5qZi5NgHWrx1CjE3";
const PROD_ADMIN_EMAIL = "sotongware@naver.com";

/**
 * Auth Emulator: create account with a fixed localId, then sign in.
 * (accounts:signUp rejects client-supplied User ID.)
 */
async function signInAsProductionAdmin() {
  const createUrl = `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts`;
  const created = await httpJson(createUrl, {
    method: "POST",
    headers: { Authorization: "Bearer owner" },
    body: {
      localId: PROD_ADMIN_UID,
      email: PROD_ADMIN_EMAIL,
      password: "Password1!",
      emailVerified: true,
    },
  });
  if (created.status !== 200) {
    throw new Error(
      `admin account create failed status=${created.status} ${created.text}`,
    );
  }
  const signInUrl = `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`;
  const signed = await httpJson(signInUrl, {
    method: "POST",
    body: {
      email: PROD_ADMIN_EMAIL,
      password: "Password1!",
      returnSecureToken: true,
    },
  });
  if (signed.status !== 200 || !signed.json.idToken) {
    throw new Error(
      `admin signIn failed status=${signed.status} ${signed.text}`,
    );
  }
  assert.equal(signed.json.localId, PROD_ADMIN_UID);
  return { uid: signed.json.localId, idToken: signed.json.idToken };
}

function stringValue(v) {
  return { stringValue: String(v) };
}
function boolValue(v) {
  return { booleanValue: !!v };
}
function mapValue(fields) {
  return { mapValue: { fields } };
}

function timestampValue(iso) {
  return { timestampValue: iso };
}

function planFields({ ownerUid, planId, updatedAt = "2026-08-13T00:00:00.000Z" }) {
  return {
    ownerUid: stringValue(ownerUid),
    planId: stringValue(planId),
    updatedAt: stringValue(updatedAt),
    isDeleted: boolValue(false),
    revision: { integerValue: "1" },
    plan: mapValue({
      id: stringValue(planId),
      status: stringValue("draft"),
      version: { integerValue: "1" },
      createdAt: stringValue(updatedAt),
      updatedAt: stringValue(updatedAt),
      input: mapValue({
        topic: stringValue("t"),
        customerProblem: stringValue("p"),
        targetCustomer: stringValue("c"),
        desiredOutcome: stringValue("o"),
        artifactType: stringValue("ebook"),
      }),
    }),
  };
}

function tombstoneFields({ ownerUid, planId }) {
  return {
    ownerUid: stringValue(ownerUid),
    planId: stringValue(planId),
    isDeleted: boolValue(true),
    deletedAt: timestampValue("2026-08-13T00:00:00.000Z"),
    updatedAt: stringValue("2026-08-13T00:00:00.000Z"),
    revision: { integerValue: "1" },
  };
}


function docPath(ownerUid, planId) {
  return `businessPlans/${ownerUid}__${planId}`;
}

async function fsGet(docPathValue, idToken) {
  const url = `http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/${docPathValue}`;
  const headers = idToken ? { Authorization: `Bearer ${idToken}` } : {};
  return httpJson(url, { headers });
}

async function fsCreate(docPathValue, idToken, fields) {
  const parts = docPathValue.split("/");
  const docId = parts.pop();
  const collection = parts.join("/");
  const url = `http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/${collection}?documentId=${encodeURIComponent(docId)}`;
  return httpJson(url, {
    method: "POST",
    headers: idToken ? { Authorization: `Bearer ${idToken}` } : {},
    body: { fields },
  });
}

async function fsPatch(docPathValue, idToken, fields) {
  const url = `http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/${docPathValue}?currentDocument.exists=true`;
  return httpJson(url, {
    method: "PATCH",
    headers: idToken ? { Authorization: `Bearer ${idToken}` } : {},
    body: { fields },
  });
}

async function fsDelete(docPathValue, idToken) {
  const url = `http://${FS_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/${docPathValue}`;
  return httpJson(url, {
    method: "DELETE",
    headers: idToken ? { Authorization: `Bearer ${idToken}` } : {},
  });
}

async function main() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    console.error(
      "FIRESTORE_EMULATOR_HOST not set — run under firebase emulators:exec",
    );
    process.exit(2);
  }
  if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    console.error(
      "FIREBASE_AUTH_EMULATOR_HOST not set — run under firebase emulators:exec",
    );
    process.exit(2);
  }

  // Ensure rules file is present (emulator loads from firebase.json).
  const rulesPath = path.join(__dirname, "..", "..", "firestore.rules");
  assert.ok(fs.existsSync(rulesPath), "firestore.rules missing");

  console.log("=== businessPlans Rules Emulator ===");
  console.log(`project=${PROJECT} auth=${AUTH_HOST} fs=${FS_HOST}`);

  const userA = await signUp(`bp_a_${Date.now()}@test.local`, "Password1!");
  const userB = await signUp(`bp_b_${Date.now()}@test.local`, "Password1!");
  pass("auth signUp owner + other");

  const planId = `plan_${Date.now()}`;
  const pathA = docPath(userA.uid, planId);

  // unauthenticated create blocked
  try {
    const res = await fsCreate(
      pathA,
      null,
      planFields({ ownerUid: userA.uid, planId }),
    );
    assert.ok(res.status === 401 || res.status === 403, `status=${res.status}`);
    pass("unauthenticated create blocked");
  } catch (e) {
    fail("unauthenticated create blocked", e);
  }

  // unauthenticated read blocked
  try {
    const res = await fsGet(pathA, null);
    assert.ok(res.status === 401 || res.status === 403 || res.status === 404);
    // If doc missing, 404 is also fine for unauth (some emulators). Prefer deny.
    pass("unauthenticated read denied-or-missing");
  } catch (e) {
    fail("unauthenticated read denied-or-missing", e);
  }

  // owner create allowed
  try {
    const res = await fsCreate(
      pathA,
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId }),
    );
    assert.equal(res.status, 200, res.text);
    pass("owner create allowed");
  } catch (e) {
    fail("owner create allowed", e);
  }

  // owner read allowed
  try {
    const res = await fsGet(pathA, userA.idToken);
    assert.equal(res.status, 200, res.text);
    pass("owner read allowed");
  } catch (e) {
    fail("owner read allowed", e);
  }

  // other user read blocked
  try {
    const res = await fsGet(pathA, userB.idToken);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("other user read blocked");
  } catch (e) {
    fail("other user read blocked", e);
  }

  // other user update blocked
  try {
    const res = await fsPatch(pathA, userB.idToken, {
      updatedAt: stringValue("2026-08-14T00:00:00.000Z"),
      ownerUid: stringValue(userA.uid),
      planId: stringValue(planId),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("other user update blocked");
  } catch (e) {
    fail("other user update blocked", e);
  }

  // other user delete blocked
  try {
    const res = await fsDelete(pathA, userB.idToken);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("other user delete blocked");
  } catch (e) {
    fail("other user delete blocked", e);
  }

  // create with forged ownerUid blocked
  try {
    const forgedId = `forged_${Date.now()}`;
    const forgedPath = docPath(userA.uid, forgedId);
    const res = await fsCreate(
      forgedPath,
      userB.idToken,
      planFields({ ownerUid: userA.uid, planId: forgedId }),
    );
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("create with forged ownerUid blocked");
  } catch (e) {
    fail("create with forged ownerUid blocked", e);
  }

  // ownerUid change on update blocked
  try {
    const res = await fsPatch(pathA, userA.idToken, {
      ownerUid: stringValue(userB.uid),
      planId: stringValue(planId),
      updatedAt: stringValue("2026-08-14T01:00:00.000Z"),
      revision: { integerValue: "2" },
      plan: mapValue({ id: stringValue(planId) }),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("ownerUid change blocked");
  } catch (e) {
    fail("ownerUid change blocked", e);
  }

  // owner update (same ownerUid) allowed with revision +1 — tombstone keys only
  try {
    const res = await fsPatch(pathA, userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(planId),
      updatedAt: stringValue("2026-08-14T02:00:00.000Z"),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T02:00:00.000Z"),
      revision: { integerValue: "2" },
    });
    assert.equal(res.status, 200, res.text);
    pass("owner tombstone update allowed");
  } catch (e) {
    fail("owner tombstone update allowed", e);
  }

  // catch-all cannot grant other user access (re-check read still denied)
  try {
    const res = await fsGet(pathA, userB.idToken);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("catch-all bypass unavailable for other user");
  } catch (e) {
    fail("catch-all bypass unavailable for other user", e);
  }

  // concurrency freshness (client-level): two sequential writes — last write with
  // newer updatedAt wins when both are owner. Rules allow both; app txn enforces.
  try {
    const concId = `conc_${Date.now()}`;
    const concPath = docPath(userA.uid, concId);
    const c1 = await fsCreate(
      concPath,
      userA.idToken,
      planFields({
        ownerUid: userA.uid,
        planId: concId,
        updatedAt: "2026-08-13T10:00:00.000Z",
      }),
    );
    assert.equal(c1.status, 200, c1.text);
    const c2 = await fsPatch(concPath, userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(concId),
      updatedAt: stringValue("2026-08-13T12:00:00.000Z"),
      revision: { integerValue: "2" },
      isDeleted: boolValue(false),
      plan: mapValue({ id: stringValue(concId) }),
    });
    assert.equal(c2.status, 200, c2.text);
    const got = await fsGet(concPath, userA.idToken);
    assert.equal(got.status, 200);
    assert.equal(
      got.json.fields.updatedAt.stringValue,
      "2026-08-13T12:00:00.000Z",
    );
    pass("owner sequential writes allowed (app enforces freshness)");
  } catch (e) {
    fail("owner sequential writes allowed (app enforces freshness)", e);
  }

  // --- Edge: namespace / tombstone-only ---
  try {
    const pid = `ns_${Date.now()}`;
    // B tries to create under A's namespace with ownerUid=B
    const res = await fsCreate(
      docPath(userA.uid, pid),
      userB.idToken,
      planFields({ ownerUid: userB.uid, planId: pid }),
    );
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("other user namespace preempt create DENY");
  } catch (e) {
    fail("other user namespace preempt create DENY", e);
  }

  try {
    const pid = `ok_${Date.now()}`;
    const res = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(res.status, 200, res.text);
    pass("correct owner namespace create ALLOW");
  } catch (e) {
    fail("correct owner namespace create ALLOW", e);
  }

  try {
    const pid = `mismatch_${Date.now()}`;
    // docId uses wrong planId suffix vs body.planId
    const res = await fsCreate(
      `businessPlans/${userA.uid}__wrong_${pid}`,
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("docId ownerUid/planId mismatch DENY");
  } catch (e) {
    fail("docId ownerUid/planId mismatch DENY", e);
  }

  try {
    const pid = `tomb_${Date.now()}`;
    const res = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(res.status, 200, res.text);
    pass("normal tombstone-only create ALLOW");
  } catch (e) {
    fail("normal tombstone-only create ALLOW", e);
  }

  try {
    const pid = `tomb_b_${Date.now()}`;
    const res = await fsCreate(
      docPath(userA.uid, pid),
      userB.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("other user tombstone create DENY");
  } catch (e) {
    fail("other user tombstone create DENY", e);
  }

  try {
    const pid = `tomb_bad_${Date.now()}`;
    const bad = {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      // missing deletedAt
      updatedAt: stringValue("2026-08-13T00:00:00.000Z"),
    };
    const res = await fsCreate(docPath(userA.uid, pid), userA.idToken, bad);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("malformed tombstone DENY");
  } catch (e) {
    fail("malformed tombstone DENY", e);
  }

  try {
    const pid = `tomb_own_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userB.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T00:00:00.000Z"),
      revision: { integerValue: "2" },
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("tombstone ownerUid change DENY");
  } catch (e) {
    fail("tombstone ownerUid change DENY", e);
  }

  try {
    const pid = `tomb_pid_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(`${pid}_changed`),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T00:00:00.000Z"),
      revision: { integerValue: "2" },
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("tombstone planId change DENY");
  } catch (e) {
    fail("tombstone planId change DENY", e);
  }

  // --- revision / tombstone type edges ---
  try {
    const pid = `ts_str_${Date.now()}`;
    const res = await fsCreate(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: stringValue("2026-08-13T00:00:00.000Z"),
      revision: { integerValue: "1" },
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("tombstone deletedAt string DENY");
  } catch (e) {
    fail("tombstone deletedAt string DENY", e);
  }

  try {
    const pid = `rev_str_${Date.now()}`;
    const res = await fsCreate(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-13T00:00:00.000Z"),
      revision: stringValue("1"),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("tombstone revision string DENY");
  } catch (e) {
    fail("tombstone revision string DENY", e);
  }

  try {
    const pid = `rev_miss_${Date.now()}`;
    const res = await fsCreate(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-13T00:00:00.000Z"),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("tombstone revision missing DENY");
  } catch (e) {
    fail("tombstone revision missing DENY", e);
  }

  try {
    const pid = `tomb_ok_${Date.now()}`;
    const res = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(res.status, 200, res.text);
    pass("normal tombstone revision int ALLOW");
  } catch (e) {
    fail("normal tombstone revision int ALLOW", e);
  }

  try {
    const pid = `plan_rev_str_${Date.now()}`;
    const fields = planFields({ ownerUid: userA.uid, planId: pid });
    fields.revision = stringValue("1");
    const res = await fsCreate(docPath(userA.uid, pid), userA.idToken, fields);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("plan revision string DENY");
  } catch (e) {
    fail("plan revision string DENY", e);
  }

  try {
    const pid = `plan_rev_miss_${Date.now()}`;
    const fields = planFields({ ownerUid: userA.uid, planId: pid });
    delete fields.revision;
    const res = await fsCreate(docPath(userA.uid, pid), userA.idToken, fields);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("plan revision missing DENY");
  } catch (e) {
    fail("plan revision missing DENY", e);
  }

  try {
    const pid = `bump_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const same = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      revision: { integerValue: "1" },
      plan: mapValue({ id: stringValue(pid) }),
      isDeleted: boolValue(false),
    });
    assert.ok(same.status === 403 || same.status === 401, `status=${same.status}`);
    pass("update revision same value DENY");

    const jump = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      revision: { integerValue: "3" },
      plan: mapValue({ id: stringValue(pid) }),
      isDeleted: boolValue(false),
    });
    assert.ok(jump.status === 403 || jump.status === 401, `status=${jump.status}`);
    pass("update revision +2 jump DENY");

    const ok = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      revision: { integerValue: "2" },
      plan: mapValue({ id: stringValue(pid) }),
      isDeleted: boolValue(false),
    });
    assert.equal(ok.status, 200, ok.text);
    pass("update revision exactly +1 ALLOW");
  } catch (e) {
    fail("update revision bump cases", e);
  }

  // --- tombstone immutability / update shape ---
  try {
    const pid = `resurrection_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(false),
      revision: { integerValue: "2" },
      plan: mapValue({ id: stringValue(pid) }),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("tombstone → live plan resurrection DENY");
  } catch (e) {
    fail("tombstone → live plan resurrection DENY", e);
  }

  try {
    const pid = `live_bad_tomb_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: stringValue("2026-08-14T00:00:00.000Z"),
      revision: { integerValue: "2" },
      plan: mapValue({ id: stringValue(pid) }),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("live plan → deletedAt string tombstone DENY");
  } catch (e) {
    fail("live plan → deletedAt string tombstone DENY", e);
  }

  try {
    const pid = `live_ok_tomb_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T00:00:00.000Z"),
      revision: { integerValue: "2" },
      updatedAt: stringValue("2026-08-14T00:00:00.000Z"),
    });
    assert.equal(res.status, 200, res.text);
    pass("live plan → normal tombstone ALLOW");
  } catch (e) {
    fail("live plan → normal tombstone ALLOW", e);
  }

  try {
    const pid = `tomb_bump_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T01:00:00.000Z"),
      revision: { integerValue: "2" },
      updatedAt: stringValue("2026-08-14T01:00:00.000Z"),
    });
    assert.equal(res.status, 200, res.text);
    pass("tombstone → tombstone revision +1 ALLOW");
  } catch (e) {
    fail("tombstone → tombstone revision +1 ALLOW", e);
  }

  try {
    const pid = `malformed_upd_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    // Neither live (missing plan) nor tombstone (isDeleted true without deletedAt).
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      revision: { integerValue: "2" },
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("malformed update DENY");
  } catch (e) {
    fail("malformed update DENY", e);
  }

  try {
    const pid = `stale_over_tomb_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    // Stale live overwrite of tombstone (resurrection attempt).
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ...planFields({ ownerUid: userA.uid, planId: pid }),
      revision: { integerValue: "2" },
      isDeleted: boolValue(false),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("stale live plan overwrite of tombstone DENY");
  } catch (e) {
    fail("stale live plan overwrite of tombstone DENY", e);
  }

  try {
    const pid = `normal_upd_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      revision: { integerValue: "2" },
      isDeleted: boolValue(false),
      plan: mapValue({ id: stringValue(pid), topic: stringValue("n") }),
      updatedAt: stringValue("2026-08-14T03:00:00.000Z"),
    });
    assert.equal(res.status, 200, res.text);
    pass("normal plan update revision +1 ALLOW");
  } catch (e) {
    fail("normal plan update revision +1 ALLOW", e);
  }

  // --- Tombstone allowed-keys ---
  try {
    const pid = `tomb_keys_ok_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T02:00:00.000Z"),
      revision: { integerValue: "2" },
      updatedAt: stringValue("2026-08-14T02:00:00.000Z"),
      syncedAt: timestampValue("2026-08-14T02:00:00.000Z"),
    });
    assert.equal(res.status, 200, res.text);
    pass("normal tombstone update ALLOW");
  } catch (e) {
    fail("normal tombstone update ALLOW", e);
  }

  try {
    const pid = `tomb_arb_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T02:00:00.000Z"),
      revision: { integerValue: "2" },
      updatedAt: stringValue("2026-08-14T02:00:00.000Z"),
      arbitraryField: stringValue("nope"),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("normal tombstone + arbitraryField DENY");
  } catch (e) {
    fail("normal tombstone + arbitraryField DENY", e);
  }

  try {
    const pid = `tomb_mal_arb_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(userA.uid, pid), userA.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      // missing deletedAt (malformed) + arbitrary
      revision: { integerValue: "2" },
      arbitraryField: stringValue("nope"),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("malformed tombstone + arbitraryField DENY");
  } catch (e) {
    fail("malformed tombstone + arbitraryField DENY", e);
  }

  // --- Physical delete DENY (owner) ---
  try {
    const pid = `del_live_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsDelete(docPath(userA.uid, pid), userA.idToken);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("owner live plan direct delete DENY");
  } catch (e) {
    fail("owner live plan direct delete DENY", e);
  }

  try {
    const pid = `del_tomb_${Date.now()}`;
    const created = await fsCreate(
      docPath(userA.uid, pid),
      userA.idToken,
      tombstoneFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsDelete(docPath(userA.uid, pid), userA.idToken);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("owner tombstone direct delete DENY");
  } catch (e) {
    fail("owner tombstone direct delete DENY", e);
  }

  // --- Production admin identity (isAdmin) — invariants still enforced ---
  const admin = await signInAsProductionAdmin();
  pass("auth signUp production admin identity");

  try {
    const pid = `admin_live_${Date.now()}`;
    const created = await fsCreate(
      docPath(admin.uid, pid),
      admin.idToken,
      planFields({ ownerUid: admin.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const bump = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      revision: { integerValue: "2" },
      isDeleted: boolValue(false),
      plan: mapValue({ id: stringValue(pid) }),
      updatedAt: stringValue("2026-08-14T04:00:00.000Z"),
    });
    assert.equal(bump.status, 200, bump.text);
    const tomb = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T04:30:00.000Z"),
      revision: { integerValue: "3" },
      updatedAt: stringValue("2026-08-14T04:30:00.000Z"),
    });
    assert.equal(tomb.status, 200, tomb.text);
    const tombBump = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T05:00:00.000Z"),
      revision: { integerValue: "4" },
      updatedAt: stringValue("2026-08-14T05:00:00.000Z"),
    });
    assert.equal(tombBump.status, 200, tombBump.text);
    pass("admin own live create / +1 / tombstone / tombstone+1 ALLOW");
  } catch (e) {
    fail("admin own live create / +1 / tombstone / tombstone+1 ALLOW", e);
  }

  try {
    const pid = `admin_res_${Date.now()}`;
    const created = await fsCreate(
      docPath(admin.uid, pid),
      admin.idToken,
      tombstoneFields({ ownerUid: admin.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(false),
      revision: { integerValue: "2" },
      plan: mapValue({ id: stringValue(pid) }),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("admin tombstone → live resurrection DENY");
  } catch (e) {
    fail("admin tombstone → live resurrection DENY", e);
  }

  try {
    const pid = `admin_mal_${Date.now()}`;
    const created = await fsCreate(
      docPath(admin.uid, pid),
      admin.idToken,
      planFields({ ownerUid: admin.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      revision: { integerValue: "2" },
      // missing deletedAt
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("admin malformed tombstone update DENY");
  } catch (e) {
    fail("admin malformed tombstone update DENY", e);
  }

  try {
    const pid = `admin_own_${Date.now()}`;
    const created = await fsCreate(
      docPath(admin.uid, pid),
      admin.idToken,
      planFields({ ownerUid: admin.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(userA.uid),
      planId: stringValue(pid),
      revision: { integerValue: "2" },
      isDeleted: boolValue(false),
      plan: mapValue({ id: stringValue(pid) }),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("admin ownerUid change DENY");
  } catch (e) {
    fail("admin ownerUid change DENY", e);
  }

  try {
    const pid = `admin_pid_${Date.now()}`;
    const created = await fsCreate(
      docPath(admin.uid, pid),
      admin.idToken,
      planFields({ ownerUid: admin.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(`${pid}_x`),
      revision: { integerValue: "2" },
      isDeleted: boolValue(false),
      plan: mapValue({ id: stringValue(`${pid}_x`) }),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("admin planId change DENY");
  } catch (e) {
    fail("admin planId change DENY", e);
  }

  try {
    const pid = `admin_ns_${Date.now()}`;
    // Admin tries to create under userA namespace with admin as ownerUid (docId mismatch)
    // or forge another owner's doc — owner-only: cannot write userA's namespace as admin.
    const res = await fsCreate(
      docPath(userA.uid, pid),
      admin.idToken,
      planFields({ ownerUid: userA.uid, planId: pid }),
    );
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("admin namespace / foreign owner write DENY");
  } catch (e) {
    fail("admin namespace / foreign owner write DENY", e);
  }

  try {
    const pid = `admin_rev_same_${Date.now()}`;
    const created = await fsCreate(
      docPath(admin.uid, pid),
      admin.idToken,
      planFields({ ownerUid: admin.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const same = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      revision: { integerValue: "1" },
      isDeleted: boolValue(false),
      plan: mapValue({ id: stringValue(pid) }),
    });
    assert.ok(same.status === 403 || same.status === 401, `status=${same.status}`);
    pass("admin revision same value DENY");

    const jump = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      revision: { integerValue: "3" },
      isDeleted: boolValue(false),
      plan: mapValue({ id: stringValue(pid) }),
    });
    assert.ok(jump.status === 403 || jump.status === 401, `status=${jump.status}`);
    pass("admin revision +2 jump DENY");

    const revStr = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      revision: stringValue("2"),
      isDeleted: boolValue(false),
      plan: mapValue({ id: stringValue(pid) }),
    });
    assert.ok(revStr.status === 403 || revStr.status === 401, `status=${revStr.status}`);
    pass("admin revision string DENY");

    const delStr = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: stringValue("2026-08-14T00:00:00.000Z"),
      revision: { integerValue: "2" },
    });
    assert.ok(delStr.status === 403 || delStr.status === 401, `status=${delStr.status}`);
    pass("admin deletedAt string DENY");
  } catch (e) {
    fail("admin revision / deletedAt type DENY cases", e);
  }

  try {
    const pid = `admin_arb_${Date.now()}`;
    const created = await fsCreate(
      docPath(admin.uid, pid),
      admin.idToken,
      tombstoneFields({ ownerUid: admin.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsPatch(docPath(admin.uid, pid), admin.idToken, {
      ownerUid: stringValue(admin.uid),
      planId: stringValue(pid),
      isDeleted: boolValue(true),
      deletedAt: timestampValue("2026-08-14T02:00:00.000Z"),
      revision: { integerValue: "2" },
      arbitraryField: stringValue("nope"),
    });
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("admin claims + arbitraryField DENY");
  } catch (e) {
    fail("admin claims + arbitraryField DENY", e);
  }

  try {
    const pid = `admin_del_live_${Date.now()}`;
    const created = await fsCreate(
      docPath(admin.uid, pid),
      admin.idToken,
      planFields({ ownerUid: admin.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsDelete(docPath(admin.uid, pid), admin.idToken);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("admin live plan direct delete DENY");
  } catch (e) {
    fail("admin live plan direct delete DENY", e);
  }

  try {
    const pid = `admin_del_tomb_${Date.now()}`;
    const created = await fsCreate(
      docPath(admin.uid, pid),
      admin.idToken,
      tombstoneFields({ ownerUid: admin.uid, planId: pid }),
    );
    assert.equal(created.status, 200, created.text);
    const res = await fsDelete(docPath(admin.uid, pid), admin.idToken);
    assert.ok(res.status === 403 || res.status === 401, `status=${res.status}`);
    pass("admin tombstone direct delete DENY");
  } catch (e) {
    fail("admin tombstone direct delete DENY", e);
  }

  const failed = results.filter((r) => !r.ok);
  console.log("\n=== Summary ===");
  console.log(`passed=${results.length - failed.length} failed=${failed.length}`);
  if (failed.length) {
    process.exit(1);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
