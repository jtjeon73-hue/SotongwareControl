"use strict";

/**
 * 전자책 canonical 18단계 — Flutter BusinessPlanningService.standardWorkflowTitles 와 동일.
 * stageId / 순서 불일치 시 relay가 거부한다.
 */
const PROBLEM_VALIDATE_EVIDENCE_CONTRACT = Object.freeze({
  minPublicSourceUrls: 5,
  minIndependentDomains: 3,
  minProblemSignals: 10,
  requiredProfiles: 2,
  directInterviewPolicy: "declare_conducted_or_not_conducted",
  noInterviewFallback: "public_voice_of_customer",
  signalIdSchemes: Object.freeze(["S", "PS"]),
});

const EBOOK_STAGE_CONTRACTS = [
  ["idea_clarify", "아이디어 정리", true, true, false, "idea_summary", "idea_contract"],
  ["problem_validate", "고객 문제 검증", true, true, false, "problem_validation", "problem_contract"],
  ["materials_prep", "자료 준비", true, true, false, "materials_index", "materials_contract"],
  ["planning", "기획", true, true, true, "ebook_plan", "planning_contract"],
  ["project_setup", "프로젝트 생성 또는 불러오기", true, true, false, "project_scaffold_report", "canonical_artifact"],
  ["prompt_generate", "AI/Cursor 작업 프롬프트 생성", true, true, false, "prompt_package", "canonical_artifact"],
  ["draft", "초안 제작", true, true, false, "manuscript_draft", "canonical_artifact"],
  ["build_test", "실행 및 기능 검사", false, true, false, "format_test_report", "canonical_artifact"],
  ["user_review", "사용자 확인", true, true, true, "review_packet", "canonical_artifact"],
  ["revise", "보완 수정", true, true, false, "revised_manuscript", "canonical_artifact"],
  ["quality", "품질 검사", true, true, false, "quality_report", "canonical_artifact"],
  ["publish_prep", "등록 준비", true, true, true, "publishing_package", "canonical_artifact"],
  ["deploy", "배포", false, false, true, "deployment_record", "canonical_artifact"],
  ["promo", "홍보자료 제작", true, true, false, "promotion_package", "canonical_artifact"],
  ["launch", "공개 및 공유", true, false, true, "launch_readiness_record", "canonical_artifact"],
  ["measure", "성과 확인", true, false, false, "measurement_plan", "canonical_artifact"],
  ["iterate", "재보완", true, true, false, "improvement_backlog", "canonical_artifact"],
  ["maintain", "유지관리", true, false, false, "maintenance_plan", "canonical_artifact"],
].map((row, index) => ({
  id: row[0],
  name: row[1],
  order: index + 1,
  applicableByDefault: row[2],
  aiDocumentStage: row[3],
  approvalTypicallyRequired: row[4],
  artifactKind: row[5],
  criteriaEvaluator: row[6],
  evidenceContract: row[0] === "problem_validate"
    ? PROBLEM_VALIDATE_EVIDENCE_CONTRACT
    : undefined,
  terminal: index === 17,
  productionBoundary: row[0] === "publish_prep",
}));

const EBOOK_STAGES = EBOOK_STAGE_CONTRACTS.map((stage) => [stage.id, stage.name]);

const EBOOK_STAGE_IDS = EBOOK_STAGES.map((s) => s[0]);
const EBOOK_STAGE_BY_ID = new Map(
  EBOOK_STAGE_CONTRACTS.map((stage) => [stage.id, stage])
);

const WORK_STATUS = new Set([
  "ready",
  "in_progress",
  "awaiting_approval",
  "completed",
  "error",
  "revision",
  "not_applicable",
  "paused_quota",
  "paused_network",
  "stalled",
  "ai_process_failed",
  "result_validation_failed",
  "result_validation_retrying",
  "stage_transition_failed",
]);

const APPROVAL_STATUS = new Set([
  "pending",
  "approved",
  "rejected",
  "revision_requested",
  "not_required",
]);

const PC_STATUS = new Set(["online", "delayed", "offline"]);

const PRODUCT_TYPES = new Set([
  "ebook",
  "app",
  "contents",
  "site",
  "promo_site",
  "industrial",
]);

module.exports = {
  EBOOK_STAGES,
  EBOOK_STAGE_CONTRACTS,
  EBOOK_STAGE_IDS,
  EBOOK_STAGE_BY_ID,
  WORK_STATUS,
  APPROVAL_STATUS,
  PC_STATUS,
  PRODUCT_TYPES,
  PROBLEM_VALIDATE_EVIDENCE_CONTRACT,
};
