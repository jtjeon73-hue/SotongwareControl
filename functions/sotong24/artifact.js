"use strict";

/**
 * Artifact signed-upload helpers for sotong24Relay.
 * TEST:  wi_test_remote_e2e_* -> sotong24/artifacts/test/...
 * PROD:  wi_plan_* + isTest=false + namespace=prod -> sotong24/artifacts/prod/...
 */

const crypto = require("crypto");
const { EBOOK_STAGE_BY_ID, PRODUCT_TYPES } = require("./canonical");
const { assertSafeId, reject } = require("./validate");

const TEST_INSTRUCTION_PREFIX = "wi_test_remote_e2e_";
const PROD_INSTRUCTION_PREFIX = "wi_plan_";
const ARTIFACT_MAX_BYTES = 1 * 1024 * 1024; // 1 MiB
const UPLOAD_URL_TTL_MS = 10 * 60 * 1000; // 10 minutes
const DOWNLOAD_URL_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days (phone open)
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
]);
const ALLOWED_CONTENT_TYPES = new Set([
  "text/markdown",
  "text/markdown; charset=utf-8",
  "text/plain",
  "text/plain; charset=utf-8",
  "application/pdf",
  "image/png",
  "image/jpeg",
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
  // Ebook: stageId is authoritative. Omit/0 stageNumber -> canonical order.
  let stageNumber;
  const rawStageNumber = body.stageNumber;
  if (rawStageNumber !== undefined && rawStageNumber !== null && rawStageNumber !== "") {
    stageNumber = assertInt(rawStageNumber, "stageNumber", {
      min: 0,
      max: 99,
      required: true,
    });
  }
  if (productType === "ebook") {
    const meta = EBOOK_STAGE_BY_ID.get(stageId);
    if (!meta) reject("invalid_argument", `unknown_ebook_stageId:${stageId}`);
    if (stageNumber === undefined || stageNumber === 0) {
      stageNumber = meta.order;
    } else if (meta.order !== stageNumber) {
      reject("invalid_argument", "ebook stageNumber_mismatch_stageId");
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

  const sizeBytes = assertInt(body.sizeBytes, "sizeBytes", {
    min: 1,
    max: 100 * 1024 * 1024,
    required: true,
  });
  if (sizeBytes > ARTIFACT_MAX_BYTES) {
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
        phase === "init" ? "artifact_upload_init" : "artifact_upload_complete",
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
    maxBytes: ARTIFACT_MAX_BYTES,
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

function createAdminStorageDeps(admin) {
  const bucket = admin.storage().bucket();
  return {
    async signUrl({ action, path, contentType, expiresMs }) {
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
  };
}

module.exports = {
  TEST_INSTRUCTION_PREFIX,
  PROD_INSTRUCTION_PREFIX,
  ARTIFACT_MAX_BYTES,
  UPLOAD_URL_TTL_MS,
  DOWNLOAD_URL_TTL_MS,
  MAX_URL_LEN,
  ALLOWED_EXTENSIONS,
  ALLOWED_CONTENT_TYPES,
  isTestInstructionId,
  isProdInstructionId,
  resolveArtifactLane,
  sanitizeHttpsUrl,
  sanitizeFileName,
  buildArtifactStoragePath,
  parseArtifactUploadInit,
  parseArtifactUploadComplete,
  createUploadGrant,
  finalizeUpload,
  createAdminStorageDeps,
  maskSignedUrlForLog,
  mapArtifactStorageError,
  scrubErrorText,
  normalizeContentType,
};
