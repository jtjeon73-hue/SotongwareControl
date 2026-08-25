"use strict";

/**
 * Artifact signed-upload helpers for sotong24Relay.
 * TEST:  wi_test_remote_e2e_* -> sotong24/artifacts/test/...
 * PROD:  wi_plan_* + isTest=false + namespace=prod -> sotong24/artifacts/prod/...
 */

const crypto = require("crypto");
const { PRODUCT_TYPES, stageMapForProduct } = require("./canonical");
const { assertSafeId, reject } = require("./validate");

const TEST_INSTRUCTION_PREFIX = "wi_test_remote_e2e_";
const PROD_INSTRUCTION_PREFIX = "wi_plan_";
const ARTIFACT_MAX_BYTES = 1 * 1024 * 1024;
const APK_ARTIFACT_MAX_BYTES = 200 * 1024 * 1024;
const APK_ARTIFACT_MIN_BYTES = 64 * 1024;
const UPLOAD_URL_TTL_MS = 10 * 60 * 1000; // 10 minutes
const DOWNLOAD_URL_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days (phone open)
const ATTACHMENT_URL_TTL_MS = 10 * 60 * 1000; // short-lived user download
const MAX_URL_LEN = 2048;
const MAX_FILENAME_LEN = 180;

// Phone-openable, non-executable deliverables. Keep active-content formats
// such as HTML/SVG outside this boundary.
const ALLOWED_EXTENSIONS = new Set([
  ".md",
  ".txt",
  ".pdf",
  ".png",
  ".jpg",
  ".jpeg",
  ".apk",
]);
const ALLOWED_CONTENT_TYPES = new Set([
  "text/markdown",
  "text/markdown; charset=utf-8",
  "text/plain",
  "text/plain; charset=utf-8",
  "application/pdf",
  "image/png",
  "image/jpeg",
  "application/vnd.android.package-archive",
]);
const ALLOWED_WORKER_TYPES = new Set(["codex", "cursor"]);
const ALLOWED_SOURCES = new Set(["ai_explicit"]);

const STORAGE_HOST_SUFFIXES = [
  "googleapis.com",
  "firebasestorage.app",
  "googleusercontent.com",
];

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

function isTestInstructionId(id) {
  return String(id || "").trim().startsWith(TEST_INSTRUCTION_PREFIX);
}

function isProdInstructionId(id) {
  return String(id || "").trim().startsWith(PROD_INSTRUCTION_PREFIX);
}

function parseBoolFlag(value) {
  if (value === undefined || value === null || value === "") return undefined;
  if (value === true || value === 1) return true;
  if (value === false || value === 0) return false;
  const s = String(value).trim().toLowerCase();
  if (s === "true" || s === "1" || s === "yes") return true;
  if (s === "false" || s === "0" || s === "no") return false;
  reject("invalid_argument", "isTest invalid_bool");
}

function namespaceFromStoragePath(path) {
  const p = String(path || "").trim();
  if (p.startsWith("sotong24/artifacts/test/")) return "test";
  if (p.startsWith("sotong24/artifacts/prod/")) return "prod";
  return null;
}

/**
 * Resolve TEST vs PROD lane.
 * Legacy TEST init (no isTest/namespace) still works for wi_test_remote_e2e_*.
 * PROD init requires explicit isTest=false + namespace=prod.
 * Complete may infer lane from storagePath.
 */
function resolveArtifactLane(body, instructionId, { requireExplicitProd = false } = {}) {
  const nsRaw =
    body.namespace !== undefined && body.namespace !== null && body.namespace !== ""
      ? String(body.namespace).trim().toLowerCase()
      : "";
  const isTestFlag = parseBoolFlag(body.isTest);
  const nsFromPath =
    body.storagePath !== undefined && body.storagePath !== null && body.storagePath !== ""
      ? namespaceFromStoragePath(body.storagePath)
      : null;

  let namespace;
  if (nsRaw === "test" || nsRaw === "prod") {
    namespace = nsRaw;
  } else if (nsRaw) {
    reject("invalid_argument", "namespace invalid_enum");
  } else if (isTestFlag === true) {
    namespace = "test";
  } else if (isTestFlag === false) {
    namespace = "prod";
  } else if (nsFromPath) {
    namespace = nsFromPath;
  } else if (isTestInstructionId(instructionId)) {
    namespace = "test"; // legacy TEST callers
  } else {
    reject("invalid_argument", "artifact_lane_unresolved", 403);
  }

  if (nsFromPath && nsFromPath !== namespace) {
    reject("invalid_artifact", "storagePath_namespace_mismatch", 403);
  }
  if (isTestFlag === true && namespace !== "test") {
    reject("invalid_artifact", "isTest_namespace_mismatch", 403);
  }
  if (isTestFlag === false && namespace !== "prod") {
    reject("invalid_artifact", "isTest_namespace_mismatch", 403);
  }

  if (namespace === "test") {
    if (!isTestInstructionId(instructionId)) {
      reject("invalid_test_instruction", "TEST instructionId required", 403);
    }
    if (isProdInstructionId(instructionId)) {
      reject("invalid_artifact", "prod_id_on_test_lane", 403);
    }
    return { namespace: "test", isTest: true };
  }

  // prod
  if (!isProdInstructionId(instructionId)) {
    reject("invalid_prod_instruction", "PROD instructionId must be wi_plan_*", 403);
  }
  if (isTestInstructionId(instructionId)) {
    reject("invalid_artifact", "test_id_on_prod_lane", 403);
  }
  if (requireExplicitProd) {
    if (isTestFlag !== false) {
      reject("invalid_prod_instruction", "prod requires isTest=false", 403);
    }
    if (nsRaw !== "prod") {
      reject("invalid_prod_instruction", "prod requires namespace=prod", 403);
    }
  }
  return { namespace: "prod", isTest: false };
}

function normalizeContentType(raw) {
  return String(raw || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function hasControlChars(s) {
  return /[\x00-\x1f\x7f]/.test(s);
}

/**
 * Reject local paths / dangerous schemes. Allow https only.
 * Optionally require Google Storage / Firebase Storage hosts (stage sync).
 */
function sanitizeHttpsUrl(value, field, { requireStorageHost = false } = {}) {
  if (value === undefined || value === null || value === "") return undefined;
  if (typeof value !== "string") {
    reject("invalid_argument", `${field} must_be_string`);
  }
  const s = value.trim();
  if (!s) return undefined;
  if (s.length > MAX_URL_LEN) reject("invalid_argument", `${field} too_long`);
  if (hasControlChars(s)) reject("invalid_argument", `${field} invalid_chars`);

  const lower = s.toLowerCase();
  if (
    lower.startsWith("javascript:") ||
    lower.startsWith("data:") ||
    lower.startsWith("file:") ||
    lower.startsWith("vbscript:")
  ) {
    reject("invalid_argument", `${field} forbidden_scheme`);
  }
  if (/^[a-zA-Z]:[\\/]/.test(s) || s.startsWith("\\\\") || s.startsWith("//")) {
    reject("invalid_argument", `${field} local_path_forbidden`);
  }
  if (s.includes("\\")) {
    reject("invalid_argument", `${field} backslash_forbidden`);
  }

  let u;
  try {
    u = new URL(s);
  } catch (_) {
    reject("invalid_argument", `${field} invalid_url`);
  }
  if (u.protocol !== "https:") {
    reject("invalid_argument", `${field} https_required`);
  }
  if (!u.hostname || u.hostname.includes("..")) {
    reject("invalid_argument", `${field} invalid_host`);
  }

  if (requireStorageHost) {
    const host = u.hostname.toLowerCase();
    const ok = STORAGE_HOST_SUFFIXES.some(
      (suf) => host === suf || host.endsWith(`.${suf}`)
    );
    if (!ok) {
      reject("invalid_argument", `${field} storage_host_required`);
    }
  }

  return s;
}

function sanitizeFileName(raw) {
  const name = String(raw ?? "").trim();
  if (!name) reject("invalid_artifact", "fileName required");
  if (name.length > MAX_FILENAME_LEN) {
    reject("invalid_artifact", "fileName too_long");
  }
  if (hasControlChars(name)) reject("invalid_artifact", "fileName invalid_chars");
  if (
    name.includes("..") ||
    name.includes("/") ||
    name.includes("\\") ||
    name.includes("\0")
  ) {
    reject("invalid_artifact", "fileName path_traversal");
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,178}$/.test(name)) {
    reject("invalid_artifact", "fileName invalid_format");
  }
  const lower = name.toLowerCase();
  const dot = lower.lastIndexOf(".");
  if (dot <= 0) reject("unsupported_artifact_type", "fileName extension_required");
  const ext = lower.slice(dot);
  if (!ALLOWED_EXTENSIONS.has(ext)) {
    reject("unsupported_artifact_type", `extension_not_allowed:${ext}`);
  }
  if (
    lower.includes("service-account") ||
    lower.endsWith(".env") ||
    lower.includes("credential") ||
    lower.includes(".p12") ||
    lower.includes(".pem") ||
    lower.includes(".key")
  ) {
    reject("unsupported_artifact_type", "fileName forbidden_pattern");
  }
  return name;
}

function sanitizeDownloadFileName(raw, revision = 1, extension = ".pdf") {
  const ext = extension === ".apk" ? ".apk" : ".pdf";
  let name = String(raw || "").trim();
  name = name
    .replace(/[<>:"/\\|?*\x00-\x1f\x7f]/g, " ")
    .replace(/\s+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^[._ ]+|[._ ]+$/g, "");
  if (!name) name = ext === ".apk" ? `SotongApp_r${revision}.apk` : `AI_ebook_final_r${revision}.pdf`;
  if (!name.toLowerCase().endsWith(ext)) name += ext;
  if (name.length > 120) {
    name = `${name.slice(0, 110).replace(/[._ ]+$/g, "")}${ext}`;
  }
  return name;
}

function buildAttachmentDisposition(fileName, revision = 1) {
  const ext = String(fileName || "").toLowerCase().endsWith(".apk") ? ".apk" : ".pdf";
  const safe = sanitizeDownloadFileName(fileName, revision, ext);
  const ascii = ext === ".apk" ? `SotongApp_r${revision}.apk` : `AI_ebook_final_r${revision}.pdf`;
  return `attachment; filename="${ascii}"; filename*=UTF-8''${encodeURIComponent(safe)}`;
}

function assertSha256Optional(value) {
  if (value === undefined || value === null || value === "") return undefined;
  const s = String(value).trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(s)) {
    reject("invalid_artifact", "sha256 invalid_format");
  }
  return s;
}

function assertWorkerType(value, { required = false } = {}) {
  if (value === undefined || value === null || value === "") {
    if (required) reject("invalid_argument", "workerType required");
    return undefined;
  }
  const w = String(value).trim().toLowerCase();
  if (!ALLOWED_WORKER_TYPES.has(w)) {
    reject("invalid_argument", "workerType not_allowed");
  }
  return w;
}

function assertSource(value, { required = false } = {}) {
  if (value === undefined || value === null || value === "") {
    if (required) reject("invalid_argument", "source required");
    return undefined;
  }
  const s = String(value).trim();
  if (!ALLOWED_SOURCES.has(s)) {
    reject("invalid_argument", "source not_allowed");
  }
  return s;
}

function assertTaskIdOptional(value, { instructionId, stageId, revision, required = false }) {
  if (value === undefined || value === null || value === "") {
    if (required) reject("invalid_argument", "taskId required");
    return undefined;
  }
  const taskId = String(value).trim();
  const expected = `${instructionId}__${stageId}__r${revision}`;
  if (taskId !== expected) {
    reject("invalid_argument", "taskId_mismatch");
  }
  return taskId;
}

/**
 * Deterministic Storage object path (server-owned).
 * sotong24/artifacts/<test|prod>/<instructionId>/<stageId>/r<revision>/<safeFileName>
 */
function buildArtifactStoragePath({
  instructionId,
  stageId,
  revision,
  fileName,
  namespace = "test",
}) {
  const id = assertSafeId(instructionId, "instructionId");
  const ns = namespace === "prod" ? "prod" : "test";
  if (ns === "test" && !isTestInstructionId(id)) {
    reject("invalid_test_instruction", "TEST instructionId required", 403);
  }
  if (ns === "prod" && !isProdInstructionId(id)) {
    reject("invalid_prod_instruction", "PROD instructionId must be wi_plan_*", 403);
  }
  const sid = assertSafeId(stageId, "stageId");
  const rev = assertInt(revision, "revision", { min: 1, max: 999, required: true });
  const safeName = sanitizeFileName(fileName);
  return `sotong24/artifacts/${ns}/${id}/${sid}/r${rev}/${safeName}`;
}

function parseArtifactUploadInit(body, { requireExplicitProd = true } = {}) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    reject("invalid_argument", "body required");
  }

  const instructionId = assertSafeId(
    body.instructionId || body.projectId,
    "instructionId"
  );
  const lane = resolveArtifactLane(body, instructionId, {
    requireExplicitProd,
  });

  const productType = String(body.productType || "ebook").trim();
  if (!PRODUCT_TYPES.has(productType)) {
    reject("invalid_argument", "productType invalid_enum");
  }

  const stageId = assertSafeId(body.stageId, "stageId");
  // Canonical production types: stageId is authoritative.
  let stageNumber;
  const rawStageNumber = body.stageNumber;
  if (rawStageNumber !== undefined && rawStageNumber !== null && rawStageNumber !== "") {
    stageNumber = assertInt(rawStageNumber, "stageNumber", {
      min: 0,
      max: 99,
      required: true,
    });
  }
  if (productType === "ebook" || productType === "app") {
    const meta = stageMapForProduct(productType).get(stageId);
    if (!meta) reject("invalid_argument", `unknown_${productType}_stageId:${stageId}`);
    if (stageNumber === undefined || stageNumber === 0) {
      stageNumber = meta.order;
    } else if (meta.order !== stageNumber) {
      reject("invalid_argument", `${productType} stageNumber_mismatch_stageId`);
    }
  } else {
    stageNumber = assertInt(body.stageNumber, "stageNumber", {
      min: 1,
      max: 99,
      required: true,
    });
  }

  const revision = assertInt(body.revision, "revision", {
    min: 1,
    max: 999,
    required: true,
  });
  const fileName = sanitizeFileName(body.fileName);
  const contentType = normalizeContentType(body.contentType);
  if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
    reject("invalid_artifact", "contentType not_allowed");
  }
  const ext = fileName.toLowerCase().slice(fileName.lastIndexOf("."));
  if (ext === ".md" && !contentType.startsWith("text/markdown")) {
    reject("invalid_artifact", "contentType_mismatch_extension");
  }
  if (ext === ".txt" && !contentType.startsWith("text/plain")) {
    reject("invalid_artifact", "contentType_mismatch_extension");
  }
  if (ext === ".pdf" && contentType !== "application/pdf") {
    reject("invalid_artifact", "contentType_mismatch_extension");
  }
  if (ext === ".png" && contentType !== "image/png") {
    reject("invalid_artifact", "contentType_mismatch_extension");
  }
  if ((ext === ".jpg" || ext === ".jpeg") && contentType !== "image/jpeg") {
    reject("invalid_artifact", "contentType_mismatch_extension");
  }
  if (ext === ".apk" && contentType !== "application/vnd.android.package-archive") {
    reject("invalid_artifact", "contentType_mismatch_extension");
  }
  const isInitialApk = productType === "app" &&
    stageId === "app_android_release" && revision === 1;
  const isRevisionApk = productType === "app" &&
    stageId === "app_production_complete" && revision >= 2;
  if (ext === ".apk" && !isInitialApk && !isRevisionApk) {
    reject("invalid_artifact", "apk_stage_revision_not_allowed", 403);
  }
  if ((isInitialApk || isRevisionApk) && ext !== ".apk") {
    reject("invalid_artifact", "apk_required_for_release_stage");
  }

  const sizeBytes = assertInt(body.sizeBytes, "sizeBytes", {
    min: 1,
    max: 2 * 1024 * 1024 * 1024,
    required: true,
  });
  const maxBytes = ext === ".apk" ? APK_ARTIFACT_MAX_BYTES : ARTIFACT_MAX_BYTES;
  if (ext === ".apk" && sizeBytes < APK_ARTIFACT_MIN_BYTES) {
    reject("invalid_artifact", "apk_size_below_minimum");
  }
  if (sizeBytes > maxBytes) {
    reject("artifact_too_large", "sizeBytes exceeds_limit", 413);
  }

  const sha256 = assertSha256Optional(body.sha256);
  const agentId =
    body.agentId !== undefined && body.agentId !== null && body.agentId !== ""
      ? assertSafeId(body.agentId, "agentId")
      : undefined;

  const strictProdMeta = requireExplicitProd && lane.namespace === "prod";
  const source = assertSource(body.source, { required: strictProdMeta });
  const workerType = assertWorkerType(body.workerType, {
    required: strictProdMeta,
  });
  const taskId = assertTaskIdOptional(body.taskId, {
    instructionId,
    stageId,
    revision,
    required: strictProdMeta,
  });

  const storagePath = buildArtifactStoragePath({
    instructionId,
    stageId,
    revision,
    fileName,
    namespace: lane.namespace,
  });

  if (body.storagePath !== undefined && body.storagePath !== null && body.storagePath !== "") {
    const claimed = String(body.storagePath).trim();
    if (claimed !== storagePath) {
      reject("invalid_artifact", "storagePath_mismatch");
    }
  }

  const artifactId = crypto
    .createHash("sha256")
    .update(`${storagePath}|${contentType}|${sizeBytes}`)
    .digest("hex")
    .slice(0, 32);

  return {
    instructionId,
    projectId: instructionId,
    productType,
    stageId,
    stageNumber,
    maxBytes,
    revision,
    fileName,
    contentType,
    sizeBytes,
    sha256,
    agentId,
    storagePath,
    artifactId,
    namespace: lane.namespace,
    isTest: lane.isTest,
    source,
    workerType,
    taskId,
  };
}

function parseArtifactUploadComplete(body) {
  // Complete may omit isTest/namespace; infer from storagePath + instructionId.
  const initLike = parseArtifactUploadInit(body, { requireExplicitProd: false });

  if (body.storagePath !== undefined && body.storagePath !== null) {
    const claimed = String(body.storagePath).trim();
    if (claimed !== initLike.storagePath) {
      reject("invalid_artifact", "storagePath_mismatch");
    }
  }
  return initLike;
}

function parseArtifactDownloadRequest(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    reject("invalid_argument", "body required");
  }
  const projectId = assertSafeId(body.projectId, "projectId");
  if (!isProdInstructionId(projectId)) {
    reject("invalid_prod_instruction", "PROD projectId must be wi_plan_*", 403);
  }
  const stageId = assertSafeId(body.stageId, "stageId");
  const productType = String(body.productType || "ebook").trim();
  if (productType !== "ebook" && productType !== "app") {
    reject("invalid_argument", "download productType invalid_enum");
  }
  if (!stageMapForProduct(productType).has(stageId)) {
    reject("invalid_argument", `unknown_${productType}_stageId:${stageId}`);
  }
  const revision = assertInt(body.revision, "revision", {
    min: 1,
    max: 999,
    required: true,
  });
  const fileName = sanitizeFileName(body.fileName);
  const expectedFile = productType === "app" ? `app-release_r${revision}.apk` : "final_ebook.pdf";
  if (productType === "app") {
    const validAppApkStage = (stageId === "app_android_release" && revision === 1) ||
      (stageId === "app_production_complete" && revision >= 2);
    if (!validAppApkStage) {
      reject("invalid_artifact", "apk_stage_revision_not_allowed", 403);
    }
  }
  if (fileName !== expectedFile) {
    reject("invalid_artifact", "download_file_not_allowed", 403);
  }
  const storagePath = buildArtifactStoragePath({
    instructionId: projectId,
    stageId,
    revision,
    fileName,
    namespace: "prod",
  });
  return {
    projectId,
    instructionId: projectId,
    stageId,
    revision,
    fileName,
    productType,
    downloadFileName: sanitizeDownloadFileName(
      body.downloadFileName,
      revision,
      productType === "app" ? ".apk" : ".pdf"
    ),
    storagePath,
    contentType: productType === "app"
      ? "application/vnd.android.package-archive"
      : "application/pdf",
  };
}

function maskSignedUrlForLog(url) {
  if (!url || typeof url !== "string") return null;
  try {
    const u = new URL(url);
    return `${u.origin}${u.pathname}?X-Goog-Signature=REDACTED`;
  } catch (_) {
    return "[redacted_url]";
  }
}

function scrubErrorText(raw) {
  return String(raw || "")
    .replace(/Bearer\s+\S+/gi, "Bearer REDACTED")
    .replace(/X-Goog-Signature=[^&\s"]+/gi, "X-Goog-Signature=REDACTED")
    .replace(/Signature=[^&\s"]+/gi, "Signature=REDACTED")
    .replace(/AIza[0-9A-Za-z_-]{20,}/g, "APIKEY_REDACTED")
    .slice(0, 240);
}

/**
 * Map Google Storage / IAM signing failures to safe client codes.
 * Does not expose SA secrets or signed URL queries.
 */
function mapArtifactStorageError(err) {
  const msg = scrubErrorText(err && err.message);
  const apiCode = scrubErrorText(
    (err && (err.code || err.status || err.statusCode)) || ""
  );
  const blob = `${msg} ${apiCode}`.toLowerCase();

  if (
    /signblob|iam\.serviceaccounts\.signblob|cannot sign data|client_email/.test(
      blob
    ) ||
    (/permission[_\s-]?denied|403|7\b/.test(blob) &&
      /sign|iamcredentials|token/.test(blob))
  ) {
    return {
      code: "artifact_signing_permission_denied",
      httpStatus: 503,
      googleApi: "signBlob",
    };
  }
  if (/iamcredentials|api .+ disabled|has not been used/.test(blob)) {
    return {
      code: "artifact_signing_api_disabled",
      httpStatus: 503,
      googleApi: "iamcredentials",
    };
  }
  if (
    /storage\.objects\.(create|get|update)|does not have storage\.|accessdenied/.test(
      blob
    )
  ) {
    return {
      code: "artifact_bucket_access_denied",
      httpStatus: 503,
      googleApi: "storage",
    };
  }
  if (/bucket.+not.?found|no such bucket|404.+bucket/.test(blob)) {
    return {
      code: "artifact_storage_unavailable",
      httpStatus: 503,
      googleApi: "bucket",
    };
  }
  return {
    code: "artifact_storage_unavailable",
    httpStatus: 500,
    googleApi: apiCode || "unknown",
  };
}

function logArtifactFailure(phase, parsed, err, mapped) {
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      tag: `[ARTIFACT] ${phase} failed`,
      operation:
        phase === "init"
          ? "artifact_upload_init"
          : phase === "download"
            ? "artifact_download"
            : "artifact_upload_complete",
      instructionId: parsed && parsed.instructionId,
      stageId: parsed && parsed.stageId,
      storagePath: parsed && parsed.storagePath,
      code: mapped.code,
      googleApi: mapped.googleApi,
      errName: err && err.name ? String(err.name) : undefined,
      errCode: scrubErrorText(err && err.code),
      errMsg: scrubErrorText(err && err.message),
    })
  );
}

function rethrowMappedArtifactError(phase, parsed, err) {
  if (err && err.code && err.httpStatus) throw err;
  const mapped = mapArtifactStorageError(err);
  logArtifactFailure(phase, parsed, err, mapped);
  reject(mapped.code, mapped.code, mapped.httpStatus);
}

async function createUploadGrant(parsed, deps, { now = Date.now() } = {}) {
  const expiresAtMs = now + UPLOAD_URL_TTL_MS;
  let uploadUrl;
  try {
    uploadUrl = await deps.signUrl({
      action: "write",
      path: parsed.storagePath,
      contentType: parsed.contentType,
      expiresMs: UPLOAD_URL_TTL_MS,
    });
  } catch (err) {
    rethrowMappedArtifactError("init", parsed, err);
  }
  return {
    ok: true,
    operation: "artifact_upload_init",
    artifactId: parsed.artifactId,
    storagePath: parsed.storagePath,
    uploadUrl,
    method: "PUT",
    expiresAt: new Date(expiresAtMs).toISOString(),
    requiredHeaders: {
      "Content-Type": parsed.contentType,
    },
    instructionId: parsed.instructionId,
    stageId: parsed.stageId,
    revision: parsed.revision,
    maxBytes: parsed.maxBytes,
    namespace: parsed.namespace,
    isTest: parsed.isTest,
  };
}

async function finalizeUpload(parsed, deps, { now = Date.now() } = {}) {
  try {
    if (typeof deps.getFileMetadata === "function") {
      const meta = await deps.getFileMetadata(parsed.storagePath);
      if (!meta || !meta.exists) {
        reject("not-found", "artifact_object_missing", 404);
      }
      if (
        meta.size !== undefined &&
        meta.size !== null &&
        Number(meta.size) !== parsed.sizeBytes
      ) {
        reject("invalid_artifact", "sizeBytes_mismatch");
      }
      if (meta.contentType) {
        const got = normalizeContentType(meta.contentType);
        const want = parsed.contentType;
        if (
          got !== want &&
          got.split(";")[0].trim() !== want.split(";")[0].trim()
        ) {
          reject("invalid_artifact", "contentType_mismatch_object");
        }
      }
    }

    const downloadUrl = await deps.signUrl({
      action: "read",
      path: parsed.storagePath,
      expiresMs: DOWNLOAD_URL_TTL_MS,
    });
    const expiresAt = new Date(now + DOWNLOAD_URL_TTL_MS).toISOString();

    return {
      ok: true,
      operation: "artifact_upload_complete",
      artifactId: parsed.artifactId,
      storagePath: parsed.storagePath,
      resultUrl: downloadUrl,
      previewUrl: downloadUrl,
      contentType: parsed.contentType,
      sizeBytes: parsed.sizeBytes,
      downloadExpiresAt: expiresAt,
      instructionId: parsed.instructionId,
      stageId: parsed.stageId,
      revision: parsed.revision,
      namespace: parsed.namespace,
      isTest: parsed.isTest,
    };
  } catch (err) {
    rethrowMappedArtifactError("complete", parsed, err);
  }
}

async function createAttachmentDownloadGrant(
  parsed,
  deps,
  { now = Date.now() } = {}
) {
  try {
    const meta = await deps.getFileMetadata(parsed.storagePath);
    if (!meta || !meta.exists) {
      reject("not-found", "artifact_object_missing", 404);
    }
    const contentType = normalizeContentType(meta.contentType);
    if (contentType.split(";")[0].trim() !== parsed.contentType) {
      reject("invalid_artifact", "contentType_mismatch_object");
    }
    const sizeBytes = Number(meta.size || 0);
    const minBytes = parsed.productType === "app" ? APK_ARTIFACT_MIN_BYTES : 1;
    const maxBytes = parsed.productType === "app"
      ? APK_ARTIFACT_MAX_BYTES
      : ARTIFACT_MAX_BYTES;
    if (!Number.isInteger(sizeBytes) || sizeBytes < minBytes || sizeBytes > maxBytes) {
      reject("invalid_artifact", "sizeBytes_out_of_range");
    }
    const responseDisposition = buildAttachmentDisposition(
      parsed.downloadFileName,
      parsed.revision
    );
    const downloadUrl = await deps.signUrl({
      action: "read",
      path: parsed.storagePath,
      expiresMs: ATTACHMENT_URL_TTL_MS,
      responseDisposition,
    });
    return {
      downloadUrl,
      fileName: parsed.downloadFileName,
      contentType: parsed.contentType,
      sizeBytes,
      expiresAt: new Date(now + ATTACHMENT_URL_TTL_MS).toISOString(),
    };
  } catch (err) {
    rethrowMappedArtifactError("download", parsed, err);
  }
}

function createAdminStorageDeps(admin) {
  const bucket = admin.storage().bucket();
  return {
    async signUrl({
      action,
      path,
      contentType,
      expiresMs,
      responseDisposition,
    }) {
      const file = bucket.file(path);
      const expires = Date.now() + (expiresMs || UPLOAD_URL_TTL_MS);
      const opts = {
        version: "v4",
        action: action === "write" ? "write" : "read",
        expires,
      };
      if (action === "write" && contentType) {
        opts.contentType = contentType;
      }
      if (action !== "write" && responseDisposition) {
        opts.responseDisposition = responseDisposition;
      }
      const [url] = await file.getSignedUrl(opts);
      return url;
    },
    async getFileMetadata(path) {
      const file = bucket.file(path);
      const [exists] = await file.exists();
      if (!exists) return { exists: false };
      const [metadata] = await file.getMetadata();
      return {
        exists: true,
        size: metadata.size !== undefined ? Number(metadata.size) : undefined,
        contentType: metadata.contentType || "",
      };
    },
    async downloadFile(path) {
      const [bytes] = await bucket.file(path).download();
      return bytes;
    },
  };
}

module.exports = {
  TEST_INSTRUCTION_PREFIX,
  PROD_INSTRUCTION_PREFIX,
  ARTIFACT_MAX_BYTES,
  APK_ARTIFACT_MAX_BYTES,
  APK_ARTIFACT_MIN_BYTES,
  UPLOAD_URL_TTL_MS,
  DOWNLOAD_URL_TTL_MS,
  ATTACHMENT_URL_TTL_MS,
  MAX_URL_LEN,
  ALLOWED_EXTENSIONS,
  ALLOWED_CONTENT_TYPES,
  isTestInstructionId,
  isProdInstructionId,
  resolveArtifactLane,
  sanitizeHttpsUrl,
  sanitizeFileName,
  sanitizeDownloadFileName,
  buildAttachmentDisposition,
  buildArtifactStoragePath,
  parseArtifactUploadInit,
  parseArtifactUploadComplete,
  parseArtifactDownloadRequest,
  createUploadGrant,
  finalizeUpload,
  createAttachmentDownloadGrant,
  createAdminStorageDeps,
  maskSignedUrlForLog,
  mapArtifactStorageError,
  scrubErrorText,
  normalizeContentType,
};
