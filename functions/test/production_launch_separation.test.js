"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  EBOOK_STAGE_BY_ID,
  WORK_STATUS,
} = require("../sotong24/canonical");
const {
  alignProjectWithCurrentStage,
  mergeMonotonicProject,
} = require("../sotong24/state_machine");

const root = path.resolve(__dirname, "../..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

test("stage18 completion becomes prelaunch review, never launched", () => {
  const out = alignProjectWithCurrentStage(
    { currentStage: 18, status: "in_progress", launchStatus: "not_started" },
    [{ stageId: "maintain", stageNumber: 18, status: "completed", approvalStatus: "not_required" }]
  );
  assert.equal(out.status, "prelaunch_review");
  assert.equal(out.productionStatus, "prelaunch_review");
  assert.equal(out.launchStatus, "not_started");
  assert.notEqual(out.status, "launched");
  assert.equal(out.externalPublished, false);
});

test("production boundary is stage18 and stages15-18 are internal AI documents", () => {
  assert.equal(EBOOK_STAGE_BY_ID.get("publish_prep").productionBoundary, false);
  assert.equal(EBOOK_STAGE_BY_ID.get("maintain").productionBoundary, true);
  for (const id of ["launch", "measure", "iterate", "maintain"]) {
    assert.equal(EBOOK_STAGE_BY_ID.get(id).aiDocumentStage, true);
  }
  assert.equal(EBOOK_STAGE_BY_ID.get("launch").approvalTypicallyRequired, false);
});

test("new production and launch statuses are relay-allowlisted", () => {
  for (const status of [
    "prelaunch_review", "awaiting_launch_approval", "launch_approved",
    "launching", "launched",
  ]) assert.equal(WORK_STATUS.has(status), true);
});

test("stale Agent full sync cannot regress launch approval or launched", () => {
  const approved = mergeMonotonicProject(
    { currentStage: 18, status: "launch_approved", productionStatus: "prelaunch_review", launchStatus: "launch_approved", finalRevision: 2, externalPublished: false },
    { currentStage: 18, status: "prelaunch_review", productionStatus: "ai_production", launchStatus: "not_started", finalRevision: 1, externalPublished: false }
  );
  assert.equal(approved.status, "launch_approved");
  assert.equal(approved.productionStatus, "prelaunch_review");
  assert.equal(approved.launchStatus, "launch_approved");

  const launched = mergeMonotonicProject(
    { currentStage: 18, status: "launched", productionStatus: "prelaunch_review", launchStatus: "launched", finalRevision: 2, externalPublished: true },
    { currentStage: 18, status: "in_progress", productionStatus: "ai_production", launchStatus: "not_started", finalRevision: 1, externalPublished: false }
  );
  assert.equal(launched.status, "launched");
  assert.equal(launched.launchStatus, "launched");
  assert.equal(launched.externalPublished, true);
});

test("newer revision may re-enter rework but never launches", () => {
  const out = mergeMonotonicProject(
    { currentStage: 18, status: "prelaunch_review", productionStatus: "prelaunch_review", launchStatus: "not_started", finalRevision: 1 },
    { currentStage: 18, status: "revision", productionStatus: "revision_in_progress", launchStatus: "not_started", finalRevision: 2, externalPublished: false }
  );
  assert.equal(out.productionStatus, "revision_in_progress");
  assert.equal(out.finalRevision, 2);
  assert.notEqual(out.launchStatus, "launched");
});

test("mobile prelaunch UI exposes separate result, review and launch actions", () => {
  const ui = read("lib/screens/product_workshop_screen.dart");
  const downloadUi = read("lib/widgets/pdf_download_button.dart");
  const allUi = `${ui}\n${downloadUi}`;
  for (const label of ["PDF 보기", "PDF 다운로드", "검토용 공유", "보완 요청", "버전 확인", "출시 준비정보", "출시 승인"]) {
    assert.match(allUi, new RegExp(label));
  }
  assert.match(ui, /수동 등록 필요/);
  assert.match(ui, /연동 미구현/);
  assert.match(ui, /아직 공개되지 않음/);
});

test("PDF view and download use distinct open and attachment paths", () => {
  const ui = read("lib/screens/product_workshop_screen.dart");
  const download = read("lib/services/pdf_download_service.dart");
  const web = read("lib/services/pdf_download_platform_web.dart");
  const artifact = read("functions/sotong24/artifact.js");
  assert.match(ui, /final_pdf_view_button[\s\S]*ResultLinkButton|ResultLinkButton[\s\S]*final_pdf_view_button/);
  assert.match(ui, /PdfDownloadButton/);
  assert.match(download, /application\/pdf/);
  assert.match(download, /hasPdfSignature/);
  assert.match(download, /hasPdfEof/);
  assert.match(download, /googleapis\.com/);
  assert.match(web, /openAttachmentUrl/);
  assert.match(artifact, /responseDisposition/);
  assert.match(artifact, /attachment; filename=/);
  assert.doesNotMatch(web, /window\.open|launchUrl/);
});

test("Launch workflow uses separate collection and blocks external actions", () => {
  const repository = read("lib/services/sotong24_remote_repository.dart");
  assert.match(repository, /collection\('launch_runs'\)/);
  assert.match(repository, /awaiting_launch_approval/);
  assert.match(repository, /blocked_until_human_approval/);
  assert.match(repository, /manual_registration_required/);
  assert.match(repository, /integrationStatus': 'not_implemented/);
  assert.doesNotMatch(repository, /externalPublished': true/);
});

test("PDF and image artifact handoff remains supported", () => {
  const artifact = read("functions/sotong24/artifact.js");
  assert.match(artifact, /application\/pdf/);
  assert.match(artifact, /image\/png/);
  assert.match(artifact, /image\/jpeg/);
});

test("prelaunch revision is an Agent request and preserves revision history", () => {
  const repository = read("lib/services/sotong24_remote_repository.dart");
  assert.match(repository, /requestPrelaunchRevision/);
  assert.match(repository, /revision_in_progress/);
  assert.match(repository, /finalRevision: nextRevision/);
  assert.match(repository, /collection\('requests'\)/);
});

test("production completion is not visually aliased to launch completion", () => {
  const models = read("lib/models/sotong24_remote_models.dart");
  assert.match(models, /제작 완료 · 출시 전 검토/);
  assert.match(models, /출시 완료/);
  assert.match(models, /launchStatus == 'launched' && externalPublished/);
});
