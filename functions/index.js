/**
 * 소통스터디부 AI 생성 + 소통24워크 PC Relay + Remote Agent API V1
 *
 * - study*: Firebase Auth + 관리자 UID
 * - sotong24Relay: Shared relay token (Bearer)
 * - api: Agent/Control HTTPS router (protocol V1)
 *   Emulator/자동 테스트 우선 — production deploy는 별도 승인
 */
const functions = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { handleRelayRequest } = require("./sotong24/relay");
const { handleApiRequest } = require("./remote/router");
const { evaluateActiveJobs, deliverNotificationEvent } = require("./remote/monitoring");
const { createAdminStorageDeps } = require("./sotong24/artifact");

if (!admin.apps.length) {
  admin.initializeApp();
}

const ADMIN_UIDS = (process.env.STUDY_ADMIN_UIDS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

async function assertAdmin(context) {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "로그인이 필요합니다."
    );
  }
  const uid = context.auth.uid;
  if (ADMIN_UIDS.length > 0 && !ADMIN_UIDS.includes(uid)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "관리자만 AI 생성을 요청할 수 있습니다."
    );
  }
  return uid;
}

function aiConfigured() {
  return Boolean(process.env.STUDY_AI_API_KEY);
}

exports.studyGenerateOutline = functions.https.onCall(async (data, context) => {
  await assertAdmin(context);
  if (!aiConfigured()) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "AI 강의 자동 생성 기능은 아직 연결되지 않았습니다. 현재는 강의 개요와 생성 조건을 저장할 수 있습니다."
    );
  }
  throw new functions.https.HttpsError(
    "unimplemented",
    "AI 공급자 어댑터가 아직 구현되지 않았습니다."
  );
});

exports.studyGenerateLesson = functions.https.onCall(async (data, context) => {
  await assertAdmin(context);
  if (!aiConfigured()) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "AI 개별 강의 생성 기능은 아직 연결되지 않았습니다."
    );
  }
  throw new functions.https.HttpsError(
    "unimplemented",
    "AI 공급자 어댑터가 아직 구현되지 않았습니다."
  );
});

exports.studyAiHealth = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  return {
    connected: aiConfigured(),
    message: aiConfigured()
      ? "AI API Key가 환경에 설정되어 있습니다."
      : "AI 강의 자동 생성 기능은 아직 연결되지 않았습니다.",
  };
});

/** PC Sotong24Work → Firestore 최소 권한 Relay (기존 유지) */
const sotong24RelaySecret = defineSecret("SOTONG24_RELAY_SECRET");

exports.sotong24Relay = onRequest(
  {
    secrets: [sotong24RelaySecret],
    cors: false,
    maxInstances: 20,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    let storageDeps = {};
    try {
      storageDeps = createAdminStorageDeps(admin);
    } catch (e) {
      // Storage bucket missing — artifact ops return 503; other relay ops still work
      console.log(
        JSON.stringify({
          ts: new Date().toISOString(),
          op: "storage_init",
          result: "unavailable",
          code: String(e && e.message ? e.message : e),
        })
      );
    }
    await handleRelayRequest(req, res, {
      getSecret: () => sotong24RelaySecret.value(),
      db: admin.firestore(),
      ...storageDeps,
    });
  }
);

/**
 * Remote Agent + Control API V1
 * Paths: /api/agent/*, /api/control/*
 */
exports.api = onRequest(
  {
    cors: false,
    maxInstances: 20,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (req, res) => {
    await handleApiRequest(req, res, {
      db: admin.firestore(),
    });
  }
);

/** Observer-only monitoring. It emits idempotent events and never changes jobs/stages. */
exports.monitorStageHealth = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Seoul", maxInstances: 1 },
  async () => {
    await evaluateActiveJobs(admin.firestore());
  }
);

/** FCM delivery is doubly gated by notification event + monitoring config mode. */
exports.deliverNotificationEvent = onDocumentCreated(
  "notificationEvents/{eventId}",
  async (event) => {
    await deliverNotificationEvent(
      admin.firestore(),
      admin.messaging(),
      event.params.eventId
    );
  }
);

exports._sotong24 = {
  handleRelayRequest,
};

exports._remote = {
  handleApiRequest,
};
