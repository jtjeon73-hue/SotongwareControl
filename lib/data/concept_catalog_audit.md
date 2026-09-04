Concept Catalog 감사 (Phase 2 Commercial Studio)

날짜: 2026-09-04
총 시드 수: 61 (변경 없음)

---

[중복·폐기 처리]

policy_rural
  변경: deprecated=true, replacementSeedId=return_farm_guide
  비고: site 변형 제목 '귀농 정책 정보관' 유지

return_farm_guide
  변경: commercial meta 추가
  비고: site 변형 제목 '귀농 정책 정보관' 유지 (통합 대체 시드)

귀농 정책 정보관 site 제목이 policy_rural·return_farm_guide 양쪽에 존재.
UI는 deprecated 시드에 replacementSeedId 안내 가능.

---

[Commercial Meta 추가 시드 — 8건]

ai_second_career — shortDescription 있음, difficulty: medium
ai_daily_assistant — shortDescription 있음, difficulty: low
ai_work_boost — difficulty: medium
online_income_start — difficulty: medium
experience_productize — difficulty: high
cashflow_retire — difficulty: medium
return_farm_guide — shortDescription 있음, difficulty: medium
gov_support_scan — difficulty: medium

---

[신규 타입]

ConceptCommercialMeta
  필드: shortDescription, customerProblem, promisedOutcome, reasonsToPay,
        uniqueValue, monetizationModels, qualityProfileTemplate,
        recommendationReason, difficulty

ConceptSeed 확장
  필드: commercial, active, deprecated, replacementSeedId, catalogVersion, updatedAt

ConceptCandidate 확장
  필드: seedId, customerProblem, promisedOutcome, reasonsToPay, uniqueValue,
        recommendationReason, deprecated, replacementSeedId, difficulty,
        catalogVersion, active

---

[집계]

전체 시드: 61
commercial meta 보유: 8
deprecated: 1 (policy_rural)
inactive: 0
