"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  APP_STAGE_CONTRACTS,
  APP_STAGE_BY_ID,
} = require("../sotong24/canonical");
const {
  createSimulation,
  currentStage,
  reportValidatedResult,
  submitDecision,
  alignProjectWithCurrentStage,
} = require("../sotong24/state_machine");
const {
  parseArtifactUploadInit,
  parseArtifactDownloadRequest,
  APK_ARTIFACT_MAX_BYTES,
} = require("../sotong24/artifact");
const { notificationContent } = require("../remote/monitoring");

test("app canonical workflow is the requested 18-stage production contract", () => {
  assert.equal(APP_STAGE_CONTRACTS.length, 18);
  assert.equal(APP_STAGE_CONTRACTS[4].id, "app_project_setup");
  assert.equal(APP_STAGE_CONTRACTS[13].id, "app_android_release");
  assert.equal(APP_STAGE_CONTRACTS[17].id, "app_production_complete");
  assert.equal(APP_STAGE_BY_ID.get("app_production_complete").productionBoundary, true);
});

test("app A completion releases state so app B can start independently", () => {
  const run = () => {
    const state = createSimulation({ productType: "app", approvalRequiredOverride: false });
    while (state.status !== "completed") reportValidatedResult(state);
    return state;
  };
  const appA = run();
  const appB = createSimulation({ productType: "app", approvalRequiredOverride: false });
  assert.equal(appA.status, "completed");
  assert.equal(currentStage(appB).stageId, "app_idea");
  assert.equal(appB.status, "in_progress");
});

test("app revision preserves r1 and resumes the same stage as r2", () => {
  const state = createSimulation({ productType: "app", approvalRequiredOverride: true });
  reportValidatedResult(state);
  const first = currentStage(state);
  const r1 = submitDecision(state, "revision_requested");
  assert.equal(r1.revision, 1);
  assert.equal(first.revision, 2);
  assert.equal(first.status, "in_progress");
  assert.equal(state.currentStageId, "app_idea");
});

test("APK artifact upload and attachment download use strict app contract", () => {
  const initial = parseArtifactUploadInit({
    instructionId: "wi_plan_APP_FOUNDATION",
    productType: "app",
    stageId: "app_android_release",
    stageNumber: 14,
    revision: 1,
    fileName: "app-release_r1.apk",
    contentType: "application/vnd.android.package-archive",
    sizeBytes: 2 * 1024 * 1024,
    isTest: false,
    namespace: "prod",
    source: "ai_explicit",
    workerType: "codex",
    taskId: "wi_plan_APP_FOUNDATION__app_android_release__r1",
  });
  assert.equal(initial.maxBytes, APK_ARTIFACT_MAX_BYTES);
  assert.match(initial.storagePath, /\/app_android_release\/r1\/app-release_r1\.apk$/);

  const body = {
    instructionId: "wi_plan_APP_FOUNDATION",
    productType: "app",
    stageId: "app_production_complete",
    stageNumber: 18,
    revision: 2,
    fileName: "app-release_r2.apk",
    contentType: "application/vnd.android.package-archive",
    sizeBytes: 2 * 1024 * 1024,
    isTest: false,
    namespace: "prod",
    source: "ai_explicit",
    workerType: "codex",
    taskId: "wi_plan_APP_FOUNDATION__app_production_complete__r2",
  };
  const upload = parseArtifactUploadInit(body);
  assert.equal(upload.productType, "app");
  assert.match(upload.storagePath, /\/app_production_complete\/r2\/app-release_r2\.apk$/);
  const download = parseArtifactDownloadRequest({
    projectId: body.instructionId,
    productType: "app",
    stageId: body.stageId,
    revision: 2,
    fileName: body.fileName,
    downloadFileName: "FarmLogAI_r2.apk",
  });
  assert.equal(download.contentType, "application/vnd.android.package-archive");
  assert.equal(download.downloadFileName, "FarmLogAI_r2.apk");
  assert.throws(
    () => parseArtifactUploadInit({ ...body, stageId: "app_android_release", stageNumber: 14 }),
    /apk_stage_revision_not_allowed/,
  );
});

test("production complete is blocked without APK and never starts Launch", () => {
  const terminal = { stageId: "app_production_complete", stageNumber: 18, status: "completed", criteriaMet: true };
  const blocked = alignProjectWithCurrentStage(
    { productType: "app", currentStage: 18, launchStatus: "not_started" },
    [terminal],
  );
  assert.equal(blocked.status, "stage_transition_failed");
  assert.equal(blocked.launchStatus, "not_started");
  assert.equal(blocked.externalPublished, false);

  const ready = alignProjectWithCurrentStage(
    { productType: "app", currentStage: 18, launchStatus: "not_started" },
    [
      {
        stageId: "app_android_release",
        stageNumber: 14,
        status: "completed",
        criteriaMet: true,
        resultUrl: "https://storage.googleapis.com/bucket/app-release_r1.apk",
      },
      terminal,
    ],
  );
  assert.equal(ready.status, "prelaunch_review");
  assert.equal(ready.productionStatus, "prelaunch_review");
  assert.equal(ready.launchStatus, "not_started");
  assert.equal(ready.externalPublished, false);
});

test("app STEP 18 reuses FCM with APK install wording", () => {
  const message = notificationContent("production_completed", 18,
    "Production Complete", 1, { productType: "app" });
  assert.equal(message.title, "앱 제작 완료");
  assert.equal(message.body, "앱 제작이 완료되었습니다. APK를 설치하여 확인해 주세요.");
});
