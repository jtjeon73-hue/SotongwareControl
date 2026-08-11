/**
 * 소통스터디부 AI 생성 + 소통24워크 PC Relay Cloud Functions
 *
 * - API Key / Relay Secret 은 Firebase Secret · 환경변수만 사용 (소스·Git 금지)
 * - study*: Firebase Auth + 관리자 UID
 * - sotong24Relay: Shared relay token (Bearer) — PC service account 키 불필요
 */
const functions = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { handleRelayRequest } = require("./sotong24/relay");

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

/** PC Sotong24Work → Firestore 최소 권한 Relay (Hosting/클라이언트 rules 불변) */
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
    await handleRelayRequest(req, res, {
      getSecret: () => sotong24RelaySecret.value(),
      db: admin.firestore(),
    });
  }
);

// 단위 테스트용 export
exports._sotong24 = {
  handleRelayRequest,
};
