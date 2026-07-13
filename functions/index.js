/**
 * 소통스터디부 AI 생성 Cloud Functions 스켈레톤
 *
 * - API Key는 Firebase Secret / 환경변수만 사용 (소스·Git에 금지)
 * - 호출 시 Firebase Auth + 관리자 UID 검증 필수
 * - 현재 AI 공급자 Key가 없으면 연결되지 않음 응답
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

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
  // 공급자 연결 시: 입력 검증 → AI 호출 → Firestore 저장
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
