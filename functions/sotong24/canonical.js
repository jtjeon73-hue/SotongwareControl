"use strict";

/**
 * 전자책 commercial v2 (Sotong24Work EbookProductionContractVersion::kStagesV2
 * + Flutter BusinessPlanningService.ebookWorkflowStages) 가 1급 계약이다.
 * 레거시 v1 stageId 는 alias map 으로만 유지한다 (fail-closed: 임의 ID 거부).
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

/**
 * Commercial ebook v2 — 18 stages.
 * Columns: id, nameKo, applicableByDefault, aiDocumentStage,
 *          approvalTypicallyRequired, artifactKind, criteriaEvaluator
 */
const EBOOK_STAGE_CONTRACTS = [
  ["idea_clarify", "아이디어 정리", true, true, false, "idea_summary", "idea_contract"],
  ["problem_validate", "고객 문제 검증", true, true, false, "problem_validation", "problem_contract"],
  ["materials_prep", "자료 준비", true, true, false, "materials_index", "materials_contract"],
  ["planning", "기획", true, true, false, "ebook_plan", "planning_contract"],
  ["project_setup", "프로젝트 생성", true, true, false, "project_scaffold_report", "ebook_project_setup_contract"],
  ["prompt_generate", "작성 프롬프트 생성", true, true, false, "prompt_package", "writing_prompt_contract"],
  ["draft", "원고 초안", true, true, false, "manuscript_draft", "manuscript_draft_contract"],
  ["editorial_structure_review", "편집·구조 검토", true, true, false, "editorial_review_report", "editorial_structure_contract"],
  ["user_review", "편집 내부 체크포인트", true, true, false, "editorial_checkpoint_packet", "ebook_editorial_checkpoint_contract"],
  ["revise", "보완 수정", true, true, false, "revised_manuscript", "manuscript_revision_contract"],
  ["quality", "품질 검사", true, true, false, "quality_report", "ebook_quality_contract"],
  ["cover_layout_design", "표지·레이아웃", true, true, false, "design_package", "ebook_design_contract"],
  ["format_build", "PDF/EPUB 빌드", true, true, false, "format_build_package", "ebook_format_build_contract"],
  ["reader_accessibility_test", "가독·접근성 검사", true, true, false, "reader_test_report", "ebook_reader_test_contract"],
  ["package_user_review", "완성형 r1 사용자 검토", true, true, true, "complete_r1_package", "ebook_package_user_review_contract"],
  ["final_polish", "최종 폴리시", true, true, false, "final_polish_report", "ebook_final_polish_contract"],
  ["final_user_approval", "최종 사용자 승인", true, true, true, "final_approval_record", "ebook_final_approval_contract"],
  ["publication_package", "출시 준비 패키지", true, true, false, "publication_package", "ebook_publication_package_contract"],
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
  productionBoundary: row[0] === "publication_package",
  commercialV2: true,
}));

const EBOOK_STAGES = EBOOK_STAGE_CONTRACTS.map((stage) => [stage.id, stage.name]);
const EBOOK_STAGE_IDS = EBOOK_STAGES.map((s) => s[0]);
const EBOOK_COMMERCIAL_V2_STAGE_IDS = Object.freeze([...EBOOK_STAGE_IDS]);

const EBOOK_STAGE_BY_ID = new Map(
  EBOOK_STAGE_CONTRACTS.map((stage) => [stage.id, stage])
);

/**
 * Legacy v1 stageIds — still accepted by relay/artifact for old WI.
 * Do not use as primary production order.
 */
const EBOOK_LEGACY_STAGE_ALIASES = [
  ["build_test", "실행 및 기능 검사", 8, false, true, false, "format_test_report"],
  ["publish_prep", "등록 준비", 12, true, true, true, "publishing_package"],
  ["deploy", "배포", 13, false, false, true, "deployment_record"],
  ["promo", "홍보자료 제작", 14, true, true, false, "promotion_package"],
  ["launch", "출시자료 준비", 15, true, true, false, "launch_preparation_package"],
  ["measure", "출시 후 운영·측정 설계", 16, true, true, false, "measurement_plan"],
  ["iterate", "개선 백로그 점검", 17, true, true, false, "improvement_backlog"],
  ["maintain", "최종 패키지 검증", 18, true, true, false, "prelaunch_final_package"],
];
for (const [id, name, order, applicable, aiDoc, approval, kind] of EBOOK_LEGACY_STAGE_ALIASES) {
  if (!EBOOK_STAGE_BY_ID.has(id)) {
    EBOOK_STAGE_BY_ID.set(id, {
      id,
      name,
      order,
      applicableByDefault: applicable,
      aiDocumentStage: aiDoc,
      approvalTypicallyRequired: approval,
      artifactKind: kind,
      criteriaEvaluator: "canonical_artifact",
      terminal: id === "maintain",
      productionBoundary: id === "maintain",
      legacyAlias: true,
    });
  }
}

// Complete-r1 legacy name used in older WI / docs.
if (!EBOOK_STAGE_BY_ID.has("sales_metadata")) {
  const gate = EBOOK_STAGE_BY_ID.get("package_user_review");
  EBOOK_STAGE_BY_ID.set("sales_metadata", {
    ...gate,
    id: "sales_metadata",
    name: "완성형 r1 사용자 검토(레거시 별칭)",
    legacyAlias: true,
    aliasOf: "package_user_review",
  });
}

/** Explicit normalize: known aliases → canonical commercial v2 id. */
const EBOOK_STAGE_ALIAS_TO_CANONICAL = Object.freeze({
  sales_metadata: "package_user_review",
});

function normalizeEbookStageId(stageId) {
  const id = String(stageId || "").trim();
  if (!id) return id;
  return EBOOK_STAGE_ALIAS_TO_CANONICAL[id] || id;
}

function resolveEbookStageMeta(stageId) {
  const normalized = normalizeEbookStageId(stageId);
  return EBOOK_STAGE_BY_ID.get(normalized) || EBOOK_STAGE_BY_ID.get(stageId) || null;
}

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
  EBOOK_COMMERCIAL_V2_STAGE_IDS,
  EBOOK_STAGE_BY_ID,
  EBOOK_LEGACY_STAGE_ALIASES,
  EBOOK_STAGE_ALIAS_TO_CANONICAL,
  normalizeEbookStageId,
  resolveEbookStageMeta,
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
