"use strict";

const {
  EBOOK_STAGE_BY_ID,
  WORK_STATUS,
  APPROVAL_STATUS,
  PC_STATUS,
  PRODUCT_TYPES,
} = require("./canonical");

const ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const MAX_STR = {
  title: 200,
  summary: 2000,
  resultPreview: 2000,
  stageName: 120,
  iso: 40,
  generic: 200,
};

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

function reject(code, message, httpStatus = 400) {
  const err = new Error(message);
  err.code = code;
  err.httpStatus = httpStatus;
  throw err;
}

function assertSafeId(value, field) {
  const s = String(value ?? "").trim();
  if (!s) reject("invalid_argument", `${field} required`);
  if (s.includes("/") || s.includes("..") || /[\x00-\x1f\x7f]/.test(s)) {
    reject("invalid_argument", `${field} path_injection`);
  }
  if (!ID_RE.test(s)) reject("invalid_argument", `${field} invalid_format`);
  return s;
}

function assertString(value, field, maxLen) {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string") reject("invalid_argument", `${field} must_be_string`);
  if (value.length > maxLen) reject("invalid_argument", `${field} too_long`);
  return value;
}

function assertIsoOptional(value, field) {
  if (value === undefined || value === null || value === "") return undefined;
  const s = assertString(value, field, MAX_STR.iso);
  const d = Date.parse(s);
  if (Number.isNaN(d)) reject("invalid_argument", `${field} invalid_iso8601`);
  return s;
}

function assertEnum(value, field, allowed) {
  if (value === undefined || value === null || value === "") return undefined;
  const s = String(value).trim();
  if (!allowed.has(s)) reject("invalid_argument", `${field} invalid_enum`);
  return s;
}

function assertInt(value, field, { min, max, required = false } = {}) {
  if (value === undefined || value === null || value === "") {
    if (required) reject("invalid_argument", `${field} required`);
    return undefined;
  }
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n) || !Number.isInteger(n)) {
    reject("invalid_argument", `${field} must_be_int`);
  }
  if (min !== undefined && n < min) reject("invalid_argument", `${field} out_of_range`);
  if (max !== undefined && n > max) reject("invalid_argument", `${field} out_of_range`);
  return n;
}

function assertBool(value, field) {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "boolean") reject("invalid_argument", `${field} must_be_bool`);
  return value;
}

/** Flutter 계약: currentStage 는 정수 stageNumber. MFC가 stageId 문자열을 보내면 변환. */
function resolveCurrentStageNumber(raw, productType) {
  if (raw === undefined || raw === null || raw === "") return undefined;
  if (typeof raw === "number" || /^[0-9]+$/.test(String(raw))) {
    return assertInt(raw, "currentStage", { min: 1, max: 99 });
  }
  const id = String(raw).trim();
  if (productType === "ebook") {
    const meta = EBOOK_STAGE_BY_ID.get(id);
    if (!meta) reject("invalid_argument", "currentStage unknown_ebook_stageId");
    return meta.order;
  }
  // 비전자책은 stageId 문자열을 숫자로 강제하지 않고 거부 → stageNumber 동봉 요구
  reject("invalid_argument", "currentStage must_be_stage_number_or_ebook_stageId");
}

function pickProjectAllowlist(input, { serverNowIso }) {
  if (!isPlainObject(input)) reject("invalid_argument", "project required");

  const projectId = assertSafeId(input.projectId, "projectId");
  const productType = assertEnum(input.productType, "productType", PRODUCT_TYPES);
  if (!productType) reject("invalid_argument", "productType required");

  const title = assertString(input.title, "title", MAX_STR.title);
  const status = assertEnum(input.status, "status", WORK_STATUS);
  const approvalStatus = assertEnum(
    input.approvalStatus,
    "approvalStatus",
    APPROVAL_STATUS
  );
  const pcStatus = assertEnum(input.pcStatus, "pcStatus", PC_STATUS);
  const progress = assertInt(input.progress, "progress", { min: 0, max: 100 });
  const totalStages = assertInt(input.totalStages, "totalStages", {
    min: 1,
    max: 99,
  });
  let currentStage = resolveCurrentStageNumber(input.currentStage, productType);
  if (
    productType === "ebook" &&
    totalStages !== undefined &&
    totalStages !== 18
  ) {
    reject("invalid_argument", "ebook totalStages must_be_18");
  }
  if (productType === "ebook" && currentStage !== undefined && currentStage > 18) {
    reject("invalid_argument", "ebook currentStage out_of_range");
  }

  // 선택: PC가 stageNumber를 명시하면 currentStage와 일치 검증
  if (input.stageNumber !== undefined && input.stageNumber !== null) {
    const sn = assertInt(input.stageNumber, "stageNumber", { min: 1, max: 99 });
    if (currentStage !== undefined && sn !== currentStage) {
      reject("invalid_argument", "stageNumber_mismatch_currentStage");
    }
    if (currentStage === undefined) currentStage = sn;
  }

  const clientUpdatedAt = assertIsoOptional(input.updatedAt, "updatedAt");
  const lastHeartbeatClient = assertIsoOptional(
    input.lastHeartbeat,
    "lastHeartbeat"
  );
  const startedAt = assertIsoOptional(input.startedAt, "startedAt");
  const contentSubtype = assertString(
    input.contentSubtype,
    "contentSubtype",
    MAX_STR.generic
  );

  // 예상 외 필드는 무시 (그대로 쓰지 않음)
  const out = {
    projectId,
    productType,
  };
  if (title !== undefined) out.title = title;
  if (contentSubtype !== undefined) out.contentSubtype = contentSubtype;
  if (currentStage !== undefined) out.currentStage = currentStage;
  if (totalStages !== undefined) out.totalStages = totalStages;
  if (progress !== undefined) out.progress = progress;
  if (status !== undefined) out.status = status;
  if (approvalStatus !== undefined) out.approvalStatus = approvalStatus;
  if (pcStatus !== undefined) out.pcStatus = pcStatus;
  if (startedAt !== undefined) out.startedAt = startedAt;

  // Flutter heartbeat: 서버 수신 시각을 lastHeartbeat로 사용 (PC 시계 조작 완화)
  out.lastHeartbeat = serverNowIso;
  out.updatedAt = serverNowIso;
  out.serverReceivedAt = serverNowIso;
  if (clientUpdatedAt !== undefined) out.clientUpdatedAt = clientUpdatedAt;
  if (lastHeartbeatClient !== undefined) {
    out.clientHeartbeatAt = lastHeartbeatClient;
  }
  // PC sync 문서는 데모가 아님
  out.isDemo = false;

  // 전자책이면 currentStageId도 보조 저장 (Flutter는 무시, MFC/디버깅용)
  if (productType === "ebook" && currentStage !== undefined) {
    for (const [id, meta] of EBOOK_STAGE_BY_ID.entries()) {
      if (meta.order === currentStage) {
        out.currentStageId = id;
        break;
      }
    }
  } else if (
    productType === "ebook" &&
    typeof input.currentStage === "string" &&
    EBOOK_STAGE_BY_ID.has(input.currentStage.trim())
  ) {
    out.currentStageId = input.currentStage.trim();
  }

  return out;
}

function pickStageAllowlist(input, { productType, serverNowIso }) {
  if (!isPlainObject(input)) reject("invalid_argument", "stage required");
  const stageId = assertSafeId(input.stageId, "stageId");
  const stageNumber = assertInt(input.stageNumber, "stageNumber", {
    min: 1,
    max: 99,
    required: true,
  });
  const stageName = assertString(input.stageName, "stageName", MAX_STR.stageName);
  const status = assertEnum(input.status, "status", WORK_STATUS);
  const approvalStatus = assertEnum(
    input.approvalStatus,
    "approvalStatus",
    APPROVAL_STATUS
  );
  const summary = assertString(input.summary, "summary", MAX_STR.summary);
  const resultPreview = assertString(
    input.resultPreview,
    "resultPreview",
    MAX_STR.resultPreview
  );
  const approvalRequired = assertBool(input.approvalRequired, "approvalRequired");
  const clientUpdatedAt = assertIsoOptional(input.updatedAt, "updatedAt");

  if (productType === "ebook") {
    const meta = EBOOK_STAGE_BY_ID.get(stageId);
    if (!meta) reject("invalid_argument", `unknown_ebook_stageId:${stageId}`);
    if (meta.order !== stageNumber) {
      reject("invalid_argument", "ebook stageNumber_mismatch_stageId");
    }
    if (stageName && stageName !== meta.name) {
      // 이름은 서버 canonical로 교정 (손상 방지)
    }
  }

  const out = {
    stageId,
    stageNumber,
  };
  if (productType === "ebook") {
    out.stageName = EBOOK_STAGE_BY_ID.get(stageId).name;
  } else if (stageName !== undefined) {
    out.stageName = stageName;
  }
  if (status !== undefined) out.status = status;
  if (summary !== undefined) out.summary = summary;
  if (resultPreview !== undefined) out.resultPreview = resultPreview;
  if (approvalRequired !== undefined) out.approvalRequired = approvalRequired;
  if (approvalStatus !== undefined) out.approvalStatus = approvalStatus;
  out.updatedAt = serverNowIso;
  out.serverReceivedAt = serverNowIso;
  if (clientUpdatedAt !== undefined) out.clientUpdatedAt = clientUpdatedAt;
  return out;
}

function assertOperations(op) {
  const allowed = new Set([
    "heartbeat",
    "project_sync",
    "stage_sync",
    "full_sync",
  ]);
  if (!allowed.has(op)) reject("invalid_argument", "operation invalid");
  return op;
}

module.exports = {
  pickProjectAllowlist,
  pickStageAllowlist,
  assertOperations,
  assertSafeId,
  reject,
  MAX_STR,
};
