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
  ["launch", "출시자료 준비", true, true, false, "launch_preparation_package", "canonical_artifact"],
  ["measure", "출시 후 운영·측정 설계", true, true, false, "measurement_plan", "canonical_artifact"],
  ["iterate", "개선 백로그 점검", true, true, false, "improvement_backlog", "canonical_artifact"],
  ["maintain", "최종 패키지 검증", true, true, false, "prelaunch_final_package", "canonical_artifact"],
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
  productionBoundary: row[0] === "maintain",
}));

const EBOOK_STAGES = EBOOK_STAGE_CONTRACTS.map((stage) => [stage.id, stage.name]);

const EBOOK_STAGE_IDS = EBOOK_STAGES.map((s) => s[0]);
const EBOOK_STAGE_BY_ID = new Map(
  EBOOK_STAGE_CONTRACTS.map((stage) => [stage.id, stage])
);

// Android-first app production. Stage 18 is an installable-APK/pre-launch
// boundary and never means Play Store submission or external publication.
const APP_STAGE_CONTRACTS = [
  ["app_idea", "앱 아이디어 정리", "app_idea_summary"],
  ["app_problem_validate", "고객 문제 검증", "app_problem_validation"],
  ["app_market_analysis", "시장·경쟁 분석", "app_market_analysis"],
  ["app_requirements", "제품 요구사항 정의", "app_requirements"],
  ["app_project_setup", "프로젝트 셋업", "flutter_project"],
  ["app_ux_flow", "UX 흐름 설계", "app_ux_flow"],
  ["app_design_system", "UI 디자인 시스템", "app_design_system"],
  ["app_data_state", "데이터·상태 구조 설계", "app_data_architecture"],
  ["app_core_implementation_1", "핵심 기능 구현 1", "app_source"],
  ["app_core_implementation_2", "핵심 기능 구현 2", "app_source"],
  ["app_integration_errors", "통합 및 예외처리", "app_integration_report"],
  ["app_code_quality", "코드 품질 점검", "flutter_analyze_report"],
  ["app_automated_tests", "자동 테스트", "flutter_test_report"],
  ["app_android_release", "Android Release Build", "android_apk"],
  ["app_device_review_prep", "실기기 검증 준비", "device_review_package"],
  ["app_user_review_package", "사용자 검토 패키지", "user_review_package"],
  ["app_revision_quality", "보완·최종 품질 검증", "app_regression_report"],
  ["app_production_complete", "Production Complete", "app_prelaunch_final_package"],
].map((row, index) => ({
  id: row[0],
  name: row[1],
  order: index + 1,
  applicableByDefault: true,
  aiDocumentStage: true,
  approvalTypicallyRequired: [4, 16, 17].includes(index + 1),
  artifactKind: row[2],
  criteriaEvaluator: index === 4
    ? "flutter_project_contract"
    : index === 13
      ? "android_apk_contract"
      : index === 17
        ? "app_prelaunch_contract"
        : "canonical_artifact",
  terminal: index === 17,
  productionBoundary: index === 17,
}));

const APP_STAGES = APP_STAGE_CONTRACTS.map((stage) => [stage.id, stage.name]);
const APP_STAGE_IDS = APP_STAGES.map((stage) => stage[0]);
const APP_STAGE_BY_ID = new Map(
  APP_STAGE_CONTRACTS.map((stage) => [stage.id, stage])
);

function stageContractsForProduct(productType) {
  if (productType === "app") return APP_STAGE_CONTRACTS;
  return EBOOK_STAGE_CONTRACTS;
}

function stageMapForProduct(productType) {
  if (productType === "app") return APP_STAGE_BY_ID;
  return EBOOK_STAGE_BY_ID;
}

const WORK_STATUS = new Set([
  "ready",
  "in_progress",
  "awaiting_approval",
  "completed",
  "error",
  "revision",
  "prelaunch_review",
  "awaiting_launch_approval",
  "launch_approved",
  "launching",
  "launched",
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
  APP_STAGES,
  APP_STAGE_CONTRACTS,
  APP_STAGE_IDS,
  APP_STAGE_BY_ID,
  stageContractsForProduct,
  stageMapForProduct,
  WORK_STATUS,
  APPROVAL_STATUS,
  PC_STATUS,
  PRODUCT_TYPES,
  PROBLEM_VALIDATE_EVIDENCE_CONTRACT,
};
