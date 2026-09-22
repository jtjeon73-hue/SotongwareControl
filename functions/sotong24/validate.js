"use strict";

const {
  stageMapForProduct,
  resolveEbookStageMeta,
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
  /** Flutter 보완 메시지 — UI maxLength 없음, summary와 동일 상한 */
  message: 2000,
};

/** Flutter Sotong24RemoteRequest.requestType */
const REQUEST_TYPES = new Set(["approve", "revision_request", "cancel"]);
const PRODUCTION_STATUS = new Set([
  "ai_production", "approval_pending", "production_complete",
  "prelaunch_review", "revision_in_progress",
]);
const LAUNCH_STATUS = new Set([
  "not_started", "awaiting_launch_approval", "launch_approved",
  "manual_registration_required", "launching", "launched",
]);

/**
 * PC가 처리할 수 있는 request.status.
 * 실기기 제출: approved | revision_requested
 * 데모/구형: pending 포함
 */
const REQUEST_ACTIONABLE_STATUS = new Set([
  "pending",
  "approved",
  "revision_requested",
]);

const REQUEST_POLL_DEFAULT_LIMIT = 5;
const REQUEST_POLL_MAX_LIMIT = 20;
const REQUEST_POLL_MAX_READ = 40;
const REQUEST_POLL_ALLOWED_KEYS = new Set([
  "operation",
  "projectId",
  "currentStageId",
  "limit",
  "productType",
]);

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

function assertIntStrict(value, field, { min, max, required = false } = {}) {
  if (value === undefined || value === null || value === "") {
    if (required) reject("invalid_argument", `${field} required`);
    return undefined;
  }
  if (typeof value !== "number") {
    reject("invalid_argument", `${field} must_be_int`);
  }
  return assertInt(value, field, { min, max, required });
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
  if (productType === "ebook" || productType === "app") {
    const meta = stageMapForProduct(productType).get(id);
    if (!meta) reject("invalid_argument", `currentStage unknown_${productType}_stageId`);
    return meta.order;
  }
  // 비전자책은 stageId 문자열을 숫자로 강제하지 않고 거부 → stageNumber 동봉 요구
  reject("invalid_argument", "currentStage must_be_stage_number_or_canonical_stageId");
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
  const productionStatus = assertEnum(input.productionStatus, "productionStatus", PRODUCTION_STATUS);
  const launchStatus = assertEnum(input.launchStatus, "launchStatus", LAUNCH_STATUS);
  const finalRevision = assertInt(input.finalRevision, "finalRevision", { min: 1, max: 9999 });
  const productionCompletedAt = assertIsoOptional(input.productionCompletedAt, "productionCompletedAt");
  const externalPublished = assertBool(input.externalPublished, "externalPublished");
  const totalStages = assertInt(input.totalStages, "totalStages", {
    min: 1,
    max: 99,
  });
  let currentStage = resolveCurrentStageNumber(input.currentStage, productType);
  if (
    (productType === "ebook" || productType === "app") &&
    totalStages !== undefined &&
    totalStages !== 18
  ) {
    reject("invalid_argument", `${productType} totalStages must_be_18`);
  }
  if ((productType === "ebook" || productType === "app") && currentStage !== undefined && currentStage > 18) {
    reject("invalid_argument", `${productType} currentStage out_of_range`);
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
	const idLooksTest = projectId.startsWith("wi_test_") || projectId.includes("e2e");
	const isTest = input.isTest === undefined ? idLooksTest : assertBool(input.isTest, "isTest");
	const environment = input.environment === undefined
	  ? (isTest ? "test" : "production")
	  : assertEnum(input.environment, "environment", new Set(["production", "test"]));
	if ((environment === "test") !== (isTest === true) || (idLooksTest && !isTest)) {
	  reject("invalid_argument", "environment_isTest_mismatch");
	}

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
  if (productionStatus !== undefined) out.productionStatus = productionStatus;
  if (launchStatus !== undefined) out.launchStatus = launchStatus;
  if (finalRevision !== undefined) out.finalRevision = finalRevision;
  if (productionCompletedAt !== undefined) out.productionCompletedAt = productionCompletedAt;
  if (externalPublished !== undefined) out.externalPublished = externalPublished;
  if (approvalStatus !== undefined) out.approvalStatus = approvalStatus;
  if (pcStatus !== undefined) out.pcStatus = pcStatus;
  if (startedAt !== undefined) out.startedAt = startedAt;
	out.environment = environment;
	out.isTest = isTest === true;

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

  // Canonical production types keep both numeric and stable stage identity.
  const canonicalMap = stageMapForProduct(productType);
  if ((productType === "ebook" || productType === "app") && currentStage !== undefined) {
    for (const [id, meta] of canonicalMap.entries()) {
      if (meta.order === currentStage) {
        out.currentStageId = id;
        break;
      }
    }
  } else if (
    (productType === "ebook" || productType === "app") &&
    typeof input.currentStage === "string" &&
    canonicalMap.has(input.currentStage.trim())
  ) {
    out.currentStageId = input.currentStage.trim();
  }

  return out;
}

/** Complete-r1 SSOT stages that may carry structured ebookReviewPackage. */
const EBOOK_REVIEW_PACKAGE_STAGE_IDS = new Set([
  "package_user_review",
  "sales_metadata",
]);
const EBOOK_REVIEW_DELIVERY_STATUS = new Set([
  "ready",
  "hold",
  "preparing",
  "failed",
  "uploading",
]);
const EBOOK_REVIEW_ARTIFACT_SLOTS = [
  "cover",
  "pdf",
  "epub",
  "manifest",
  "qualityReport",
];
const MAX_EBOOK_REVIEW_PACKAGE = {
  holdReason: 240,
  revisionLabel: 16,
  sha256: 64,
  relPath: 260,
  title: 200,
  subtitle: 200,
  author: 120,
  language: 16,
  fileName: 180,
  artifactId: 220,
  uploadStatus: 40,
  grantType: 40,
  remoteStatus: 40,
  schemaVersion: 64,
  generatedAt: 40,
  tocItem: 200,
  tocCount: 40,
  serializedChars: 48000,
};

function assertRelativePublishPath(value, field) {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") {
    reject("invalid_argument", `${field} must_be_string`);
  }
  const s = value.trim();
  if (!s) return undefined;
  if (s.length > MAX_EBOOK_REVIEW_PACKAGE.relPath) {
    reject("invalid_argument", `${field} too_long`);
  }
  if (/[\x00-\x1f\x7f]/.test(s) || s.includes("\\") || s.includes("..")) {
    reject("invalid_argument", `${field} invalid_path`);
  }
  if (/^[a-zA-Z]:[\\/]/.test(s) || s.startsWith("/") || s.startsWith("//")) {
    reject("invalid_argument", `${field} absolute_path_forbidden`);
  }
  if (!(s.startsWith("publish/") || s.startsWith("output/"))) {
    reject("invalid_argument", `${field} path_prefix_forbidden`);
  }
  return s;
}

function assertSha256Hex(value, field) {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") {
    reject("invalid_argument", `${field} must_be_string`);
  }
  const s = value.trim().toLowerCase();
  if (!s) return undefined;
  if (s.length !== MAX_EBOOK_REVIEW_PACKAGE.sha256) {
    reject("invalid_argument", `${field} invalid_sha256`);
  }
  if (!/^[0-9a-f]+$/.test(s)) {
    reject("invalid_argument", `${field} invalid_sha256`);
  }
  return s;
}

function pickEbookReviewArtifactSlot(raw, slotName) {
  if (raw === undefined || raw === null) return undefined;
  if (!isPlainObject(raw)) {
    reject("invalid_argument", `ebookReviewPackage.${slotName} must_be_object`);
  }
  const { sanitizeHttpsUrl } = require("./artifact");
  const out = {};
  const fileName = assertString(
    raw.fileName,
    `ebookReviewPackage.${slotName}.fileName`,
    MAX_EBOOK_REVIEW_PACKAGE.fileName
  );
  if (fileName !== undefined) out.fileName = fileName;
  const path = assertRelativePublishPath(
    raw.path,
    `ebookReviewPackage.${slotName}.path`
  );
  if (path !== undefined) out.path = path;
  const sha256 = assertSha256Hex(
    raw.sha256,
    `ebookReviewPackage.${slotName}.sha256`
  );
  if (sha256 !== undefined) out.sha256 = sha256;
  const size = assertInt(raw.size, `ebookReviewPackage.${slotName}.size`, {
    min: 0,
    max: 50 * 1024 * 1024,
  });
  if (size !== undefined) out.size = size;
  const width = assertInt(raw.width, `ebookReviewPackage.${slotName}.width`, {
    min: 1,
    max: 20000,
  });
  if (width !== undefined) out.width = width;
  const height = assertInt(raw.height, `ebookReviewPackage.${slotName}.height`, {
    min: 1,
    max: 20000,
  });
  if (height !== undefined) out.height = height;
  const pageCount = assertInt(
    raw.pageCount,
    `ebookReviewPackage.${slotName}.pageCount`,
    { min: 1, max: 5000 }
  );
  if (pageCount !== undefined) out.pageCount = pageCount;
  for (const flag of ["grantReady", "remoteReady", "uploaded"]) {
    const v = assertBool(raw[flag], `ebookReviewPackage.${slotName}.${flag}`);
    if (v !== undefined) out[flag] = v;
  }
  const grantType = assertString(
    raw.grantType,
    `ebookReviewPackage.${slotName}.grantType`,
    MAX_EBOOK_REVIEW_PACKAGE.grantType
  );
  if (grantType !== undefined) out.grantType = grantType;
  const uploadStatus = assertString(
    raw.uploadStatus,
    `ebookReviewPackage.${slotName}.uploadStatus`,
    MAX_EBOOK_REVIEW_PACKAGE.uploadStatus
  );
  if (uploadStatus !== undefined) out.uploadStatus = uploadStatus;
  const remoteStatus = assertString(
    raw.remoteStatus,
    `ebookReviewPackage.${slotName}.remoteStatus`,
    MAX_EBOOK_REVIEW_PACKAGE.remoteStatus
  );
  if (remoteStatus !== undefined) out.remoteStatus = remoteStatus;
  const artifactId = assertString(
    raw.artifactId,
    `ebookReviewPackage.${slotName}.artifactId`,
    MAX_EBOOK_REVIEW_PACKAGE.artifactId
  );
  if (artifactId !== undefined) {
    if (artifactId.includes("..") || /[\x00-\x1f\x7f]/.test(artifactId)) {
      reject(
        "invalid_argument",
        `ebookReviewPackage.${slotName}.artifactId invalid_chars`
      );
    }
    out.artifactId = artifactId;
  }
  const remoteUrl = sanitizeHttpsUrl(
    raw.remoteUrl,
    `ebookReviewPackage.${slotName}.remoteUrl`,
    { requireStorageHost: true }
  );
  if (remoteUrl !== undefined) out.remoteUrl = remoteUrl;
  return Object.keys(out).length > 0 ? out : undefined;
}

function pickEbookReviewQuality(raw) {
  if (raw === undefined || raw === null) return undefined;
  if (!isPlainObject(raw)) {
    reject("invalid_argument", "ebookReviewPackage.quality must_be_object");
  }
  const out = {};
  const score = assertInt(raw.score ?? raw.qualityScore, "ebookReviewPackage.quality.score", {
    min: 0,
    max: 100,
  });
  if (score !== undefined) out.score = score;
  for (const key of ["criticalCount", "majorCount", "refineCount"]) {
    const v = assertInt(raw[key], `ebookReviewPackage.quality.${key}`, {
      min: 0,
      max: 10000,
    });
    if (v !== undefined) out[key] = v;
  }
  const reportPath = assertRelativePublishPath(
    raw.reportPath,
    "ebookReviewPackage.quality.reportPath"
  );
  if (reportPath !== undefined) out.reportPath = reportPath;
  const reportSHA256 = assertSha256Hex(
    raw.reportSHA256,
    "ebookReviewPackage.quality.reportSHA256"
  );
  if (reportSHA256 !== undefined) out.reportSHA256 = reportSHA256;
  const evaluatedAt = assertIsoOptional(
    raw.evaluatedAt,
    "ebookReviewPackage.quality.evaluatedAt"
  );
  if (evaluatedAt !== undefined) out.evaluatedAt = evaluatedAt;
  return Object.keys(out).length > 0 ? out : undefined;
}

/**
 * Allow only Control-needed complete-r1 SSOT fields.
 * Drop manuscript/structure/stagingToken and other bulk/secret-adjacent keys.
 * Present-but-invalid → fail-closed. Wrong product/stage → omit (ignore).
 */
function pickEbookReviewPackage(raw, { productType, stageId }) {
  if (raw === undefined || raw === null) return undefined;
  if (productType !== "ebook" || !EBOOK_REVIEW_PACKAGE_STAGE_IDS.has(stageId)) {
    return undefined;
  }
  if (!isPlainObject(raw)) {
    reject("invalid_argument", "ebookReviewPackage must_be_object");
  }

  const schemaVersion = assertString(
    raw.schemaVersion,
    "ebookReviewPackage.schemaVersion",
    MAX_EBOOK_REVIEW_PACKAGE.schemaVersion
  );
  const contractVersion = assertInt(
    raw.contractVersion,
    "ebookReviewPackage.contractVersion",
    { min: 1, max: 9 }
  );
  const schemaOk =
    (typeof schemaVersion === "string" &&
      schemaVersion.includes("ebookReviewPackage")) ||
    contractVersion === 2;
  if (!schemaOk) {
    reject("invalid_argument", "ebookReviewPackage schema_unsupported");
  }

  const out = {};
  if (schemaVersion !== undefined) out.schemaVersion = schemaVersion;
  if (contractVersion !== undefined) out.contractVersion = contractVersion;

  const reviewReady = assertBool(raw.reviewReady, "ebookReviewPackage.reviewReady");
  if (reviewReady !== undefined) out.reviewReady = reviewReady;
  const deliveryStatus = assertEnum(
    raw.deliveryStatus,
    "ebookReviewPackage.deliveryStatus",
    EBOOK_REVIEW_DELIVERY_STATUS
  );
  if (deliveryStatus !== undefined) out.deliveryStatus = deliveryStatus;
  const holdReason = assertString(
    raw.holdReason,
    "ebookReviewPackage.holdReason",
    MAX_EBOOK_REVIEW_PACKAGE.holdReason
  );
  if (holdReason !== undefined) out.holdReason = holdReason;

  const revisionLabel = assertString(
    raw.revision,
    "ebookReviewPackage.revision",
    MAX_EBOOK_REVIEW_PACKAGE.revisionLabel
  );
  if (revisionLabel !== undefined) {
    if (!/^r?[0-9]{1,3}$/i.test(revisionLabel.trim())) {
      reject("invalid_argument", "ebookReviewPackage.revision invalid_format");
    }
    out.revision = revisionLabel.trim().toLowerCase().startsWith("r")
      ? revisionLabel.trim().toLowerCase()
      : `r${revisionLabel.trim()}`;
  }

  const manifestSHA256 = assertSha256Hex(
    raw.manifestSHA256,
    "ebookReviewPackage.manifestSHA256"
  );
  if (manifestSHA256 !== undefined) out.manifestSHA256 = manifestSHA256;

  for (const key of ["title", "subtitle", "author", "language", "projectName"]) {
    const max =
      key === "author" || key === "language"
        ? MAX_EBOOK_REVIEW_PACKAGE[key === "language" ? "language" : "author"]
        : MAX_EBOOK_REVIEW_PACKAGE.title;
    const v = assertString(raw[key], `ebookReviewPackage.${key}`, max);
    if (v !== undefined) out[key] = v;
  }
  for (const idField of ["projectId", "instructionId"]) {
    if (raw[idField] === undefined || raw[idField] === null || raw[idField] === "") {
      continue;
    }
    out[idField] = assertSafeId(raw[idField], `ebookReviewPackage.${idField}`);
  }
  if (raw.stageId !== undefined && raw.stageId !== null && raw.stageId !== "") {
    const pkgStage = assertSafeId(raw.stageId, "ebookReviewPackage.stageId");
    // Keep review stages; format_build may appear as frozen provenance.
    if (
      EBOOK_REVIEW_PACKAGE_STAGE_IDS.has(pkgStage) ||
      pkgStage === "format_build"
    ) {
      out.stageId = pkgStage;
    }
  }

  for (const flag of ["frozen", "promoteToUserR1"]) {
    const v = assertBool(raw[flag], `ebookReviewPackage.${flag}`);
    if (v !== undefined) out[flag] = v;
  }
  for (const ts of ["generatedAt", "validatedAt", "frozenAt"]) {
    const v = assertIsoOptional(raw[ts], `ebookReviewPackage.${ts}`);
    if (v !== undefined) out[ts] = v;
  }
  for (const key of [
    "qualityScore",
    "criticalCount",
    "majorCount",
    "refineCount",
    "pageCount",
    "chapterCount",
  ]) {
    const v = assertInt(raw[key], `ebookReviewPackage.${key}`, {
      min: 0,
      max: key === "qualityScore" ? 100 : 100000,
    });
    if (v !== undefined) out[key] = v;
  }

  const immutablePath = assertRelativePublishPath(
    raw.immutablePath,
    "ebookReviewPackage.immutablePath"
  );
  if (immutablePath !== undefined) out.immutablePath = immutablePath;

  if (isPlainObject(raw.fileSizes)) {
    const fileSizes = {};
    for (const k of ["pdf", "epub", "cover", "manifest"]) {
      const v = assertInt(raw.fileSizes[k], `ebookReviewPackage.fileSizes.${k}`, {
        min: 0,
        max: 50 * 1024 * 1024,
      });
      if (v !== undefined) fileSizes[k] = v;
    }
    if (Object.keys(fileSizes).length > 0) out.fileSizes = fileSizes;
  }

  const quality = pickEbookReviewQuality(raw.quality);
  if (quality !== undefined) out.quality = quality;

  for (const slot of EBOOK_REVIEW_ARTIFACT_SLOTS) {
    const artifact = pickEbookReviewArtifactSlot(raw[slot], slot);
    if (artifact !== undefined) out[slot] = artifact;
  }

  // Optional short TOC labels only (no manuscript/structure dump).
  const tocRaw = raw.tocSummary ?? raw.toc;
  if (Array.isArray(tocRaw)) {
    const tocSummary = [];
    for (let i = 0; i < tocRaw.length && tocSummary.length < MAX_EBOOK_REVIEW_PACKAGE.tocCount; i++) {
      const item = tocRaw[i];
      if (typeof item !== "string") continue;
      const s = item.trim();
      if (!s || s.length > MAX_EBOOK_REVIEW_PACKAGE.tocItem) continue;
      if (/[\x00-\x1f\x7f]/.test(s)) continue;
      tocSummary.push(s);
    }
    if (tocSummary.length > 0) out.tocSummary = tocSummary;
  }

  const serialized = JSON.stringify(out);
  if (serialized.length > MAX_EBOOK_REVIEW_PACKAGE.serializedChars) {
    reject("invalid_argument", "ebookReviewPackage too_large");
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
  const criteriaMet = assertBool(input.criteriaMet, "criteriaMet");
  const clientUpdatedAt = assertIsoOptional(input.updatedAt, "updatedAt");
  const startedAt = assertIsoOptional(input.startedAt, "startedAt");
  const completedAt = assertIsoOptional(input.completedAt, "completedAt");
  const workDurationMs = assertIntStrict(input.workDurationMs, "workDurationMs", {
    min: 0,
  });
  const revision = assertInt(input.revision, "revision", { min: 0 });

  if (productType === "ebook" || productType === "app") {
    const meta = productType === "ebook"
      ? resolveEbookStageMeta(stageId)
      : stageMapForProduct(productType).get(stageId);
    if (!meta) reject("invalid_argument", `unknown_${productType}_stageId:${stageId}`);
    if (meta.order !== stageNumber) {
      reject("invalid_argument", `${productType} stageNumber_mismatch_stageId`);
    }
    if (stageName && stageName !== meta.name) {
      // 이름은 서버 canonical로 교정 (손상 방지)
    }
  }

  const out = {
    stageId,
    stageNumber,
  };
  if (productType === "ebook" || productType === "app") {
    out.stageName = stageMapForProduct(productType).get(stageId).name;
  } else if (stageName !== undefined) {
    out.stageName = stageName;
  }
  if (status !== undefined) out.status = status;
  if (summary !== undefined) out.summary = summary;
  if (resultPreview !== undefined) out.resultPreview = resultPreview;
  // resultUrl / previewUrl — https only, Storage host required (no local/file/js)
  const { sanitizeHttpsUrl } = require("./artifact");
  const resultUrl = sanitizeHttpsUrl(input.resultUrl, "resultUrl", {
    requireStorageHost: true,
  });
  const previewUrl = sanitizeHttpsUrl(input.previewUrl, "previewUrl", {
    requireStorageHost: true,
  });
  if (resultUrl !== undefined) out.resultUrl = resultUrl;
  if (previewUrl !== undefined) out.previewUrl = previewUrl;
  if (approvalRequired !== undefined) out.approvalRequired = approvalRequired;
  if (criteriaMet !== undefined) out.criteriaMet = criteriaMet;
  if (approvalStatus !== undefined) out.approvalStatus = approvalStatus;
  if (startedAt !== undefined) out.startedAt = startedAt;
  if (completedAt !== undefined) out.completedAt = completedAt;
  if (workDurationMs !== undefined) out.workDurationMs = workDurationMs;
  if (revision !== undefined) out.revision = revision;

  const ebookReviewPackage = pickEbookReviewPackage(input.ebookReviewPackage, {
    productType,
    stageId,
  });
  if (ebookReviewPackage !== undefined) {
    out.ebookReviewPackage = ebookReviewPackage;
  }

  if (
    (status === "completed" || status === "awaiting_approval") &&
    criteriaMet !== true
  ) {
    reject("failed-precondition", "completed_stage_requires_criteriaMet_true");
  }
  if (status === "awaiting_approval" && approvalRequired !== true) {
    reject("failed-precondition", "awaiting_approval_requires_approvalRequired_true");
  }
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
    "request_poll",
    "request_applied",
    "artifact_upload_init",
    "artifact_upload_complete",
    "artifact_apk_ready_replay_test",
    "review_artifact_upload_init",
    "review_artifact_upload_complete",
  ]);
  if (!allowed.has(op)) reject("invalid_argument", "operation invalid");
  return op;
}

function parseRequestAppliedInput(body) {
  if (!isPlainObject(body)) reject("invalid_argument", "body required");
  const allowed = new Set([
    "operation",
    "projectId",
    "requestId",
    "completedStageId",
    "nextStageIdPrepared",
  ]);
  for (const key of Object.keys(body)) {
    if (!allowed.has(key)) reject("invalid_argument", `unexpected_field:${key}`);
  }
  const nextStageIdPrepared = String(body.nextStageIdPrepared || "").trim();
  if (nextStageIdPrepared) {
    assertSafeId(nextStageIdPrepared, "nextStageIdPrepared");
  }
  return {
    projectId: assertSafeId(body.projectId, "projectId"),
    requestId: assertSafeId(body.requestId, "requestId"),
    completedStageId: assertSafeId(body.completedStageId, "completedStageId"),
    nextStageIdPrepared,
  };
}

/**
 * request_poll 입력 — top-level만, 경로 주입 금지, 알 수 없는 필드 거부.
 */
function parseRequestPollInput(body) {
  if (!isPlainObject(body)) reject("invalid_argument", "body required");
  for (const key of Object.keys(body)) {
    if (!REQUEST_POLL_ALLOWED_KEYS.has(key)) {
      reject("invalid_argument", `unexpected_field:${key}`);
    }
  }

  const projectId = assertSafeId(body.projectId, "projectId");
  const currentStageId = assertSafeId(body.currentStageId, "currentStageId");
  const productType =
    assertEnum(body.productType, "productType", PRODUCT_TYPES) || "ebook";

  if (productType === "ebook" || productType === "app") {
    if (!stageMapForProduct(productType).has(currentStageId)) {
      reject("invalid_argument", `currentStageId unknown_${productType}_stageId`);
    }
  }

  let limit = REQUEST_POLL_DEFAULT_LIMIT;
  if (body.limit !== undefined && body.limit !== null && body.limit !== "") {
    limit = assertInt(body.limit, "limit", {
      min: 1,
      max: REQUEST_POLL_MAX_LIMIT,
      required: true,
    });
  }

  return { projectId, currentStageId, productType, limit };
}

/**
 * 프로젝트 currentStage ↔ poll currentStageId 교차검증.
 * currentStage/currentStageId가 없으면 통과(요청 stage 필터만 적용).
 */
function assertProjectStageAlignment(projectData, currentStageId, productType) {
  if (!isPlainObject(projectData)) return;
  if (projectData.currentStageId) {
    const pid = String(projectData.currentStageId).trim();
    if (pid && pid !== currentStageId) {
      reject("invalid_argument", "currentStageId mismatch_project");
    }
  } else if (
    (productType === "ebook" || productType === "app") &&
    projectData.currentStage !== undefined &&
    projectData.currentStage !== null &&
    projectData.currentStage !== ""
  ) {
    const meta = stageMapForProduct(productType).get(currentStageId);
    const n = Number(projectData.currentStage);
    if (meta && Number.isFinite(n) && n !== meta.order) {
      reject("invalid_argument", "currentStageId mismatch_project");
    }
  }
}

function toIsoStringMaybe(value) {
  if (value === undefined || value === null || value === "") return "";
  if (typeof value === "string") {
    if (value.length > MAX_STR.iso) return null;
    return value;
  }
  // Firestore Timestamp-like
  if (typeof value.toDate === "function") {
    try {
      return value.toDate().toISOString();
    } catch (_) {
      return null;
    }
  }
  if (typeof value === "object" && typeof value._seconds === "number") {
    return new Date(value._seconds * 1000).toISOString();
  }
  return null;
}

/**
 * Firestore request 문서 → PC 응답 allowlist.
 * 비정상/과대 message/필수 누락 → null (제외).
 */
function pickRequestAllowlist(raw, { docId, expectedProjectId, currentStageId }) {
  if (!isPlainObject(raw)) return null;
  const requestId = assertSafeIdLoose(
    raw.requestId || docId,
    "requestId"
  );
  if (!requestId) return null;

  const projectId = String(raw.projectId ?? "").trim();
  if (projectId !== expectedProjectId) return null;
  if (
    projectId.includes("/") ||
    projectId.includes("..") ||
    !ID_RE.test(projectId)
  ) {
    return null;
  }

  const stageId = String(raw.stageId ?? "").trim();
  const requestType = String(raw.requestType ?? "").trim();
  if (!REQUEST_TYPES.has(requestType)) return null;

  if (requestType === "cancel") {
    if (
      stageId &&
      (stageId.includes("/") ||
        stageId.includes("..") ||
        !ID_RE.test(stageId) ||
        stageId !== currentStageId)
    ) {
      return null;
    }
  } else {
    if (!stageId || stageId !== currentStageId) return null;
    if (
      stageId.includes("/") ||
      stageId.includes("..") ||
      !ID_RE.test(stageId)
    ) {
      return null;
    }
  }

  const status = String(raw.status ?? "").trim();
  if (!REQUEST_ACTIONABLE_STATUS.has(status)) return null;

  if (typeof raw.message !== "string" && raw.message != null) return null;
  const message = raw.message == null ? "" : String(raw.message);
  if (message.length > MAX_STR.message) return null;

  const createdAt = toIsoStringMaybe(raw.createdAt);
  const updatedAt = toIsoStringMaybe(raw.updatedAt);
  const processedAt = toIsoStringMaybe(raw.processedAt);
  if (createdAt === null || updatedAt === null || processedAt === null) {
    return null;
  }

  const revision = Number.isInteger(Number(raw.revision))
    ? Math.max(0, Number(raw.revision))
    : 0;
  return {
    requestId,
    projectId,
    stageId: requestType === "cancel" && !stageId ? currentStageId : stageId,
    requestType,
    status,
    message,
    createdAt,
    updatedAt,
    processedAt,
    revision,
    processed: raw.processed === true,
    workflowApplied: raw.workflowApplied === true,
    workflowAppliedAt: toIsoStringMaybe(raw.workflowAppliedAt) || "",
  };
}

/** throw 대신 null — poll 필터용 */
function assertSafeIdLoose(value) {
  const s = String(value ?? "").trim();
  if (!s) return null;
  if (s.includes("/") || s.includes("..") || /[\x00-\x1f\x7f]/.test(s)) {
    return null;
  }
  if (!ID_RE.test(s)) return null;
  return s;
}

function sortRequestsNewestFirst(a, b) {
  const ac = a.createdAt || "";
  const bc = b.createdAt || "";
  if (ac === bc) return 0;
  return ac < bc ? 1 : -1;
}

module.exports = {
  pickProjectAllowlist,
  pickStageAllowlist,
  pickEbookReviewPackage,
  pickRequestAllowlist,
  parseRequestPollInput,
  parseRequestAppliedInput,
  assertProjectStageAlignment,
  assertOperations,
  assertSafeId,
  reject,
  sortRequestsNewestFirst,
  MAX_STR,
  EBOOK_REVIEW_PACKAGE_STAGE_IDS,
  REQUEST_TYPES,
  REQUEST_ACTIONABLE_STATUS,
  REQUEST_POLL_DEFAULT_LIMIT,
  REQUEST_POLL_MAX_LIMIT,
  REQUEST_POLL_MAX_READ,
};
