"use strict";

/**
 * 전자책 canonical 18단계 — Flutter BusinessPlanningService.standardWorkflowTitles 와 동일.
 * stageId / 순서 불일치 시 relay가 거부한다.
 */
const EBOOK_STAGES = [
  ["idea_clarify", "아이디어 정리"],
  ["problem_validate", "고객 문제 검증"],
  ["materials_prep", "자료 준비"],
  ["planning", "기획"],
  ["project_setup", "프로젝트 생성 또는 불러오기"],
  ["prompt_generate", "AI/Cursor 작업 프롬프트 생성"],
  ["draft", "초안 제작"],
  ["build_test", "실행 및 기능 검사"],
  ["user_review", "사용자 확인"],
  ["revise", "보완 수정"],
  ["quality", "품질 검사"],
  ["publish_prep", "등록 준비"],
  ["deploy", "배포"],
  ["promo", "홍보자료 제작"],
  ["launch", "공개 및 공유"],
  ["measure", "성과 확인"],
  ["iterate", "재보완"],
  ["maintain", "유지관리"],
];

const EBOOK_STAGE_IDS = EBOOK_STAGES.map((s) => s[0]);
const EBOOK_STAGE_BY_ID = new Map(
  EBOOK_STAGES.map((s, i) => [s[0], { id: s[0], name: s[1], order: i + 1 }])
);

const WORK_STATUS = new Set([
  "ready",
  "in_progress",
  "awaiting_approval",
  "completed",
  "error",
  "revision",
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
  EBOOK_STAGE_IDS,
  EBOOK_STAGE_BY_ID,
  WORK_STATUS,
  APPROVAL_STATUS,
  PC_STATUS,
  PRODUCT_TYPES,
};
