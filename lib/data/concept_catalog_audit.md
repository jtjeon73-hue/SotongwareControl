Concept Catalog 감사 (Phase 2 보완 검증)

날짜: 2026-09-04
정본 HEAD 기준: 845e2de → 본 보완 커밋

==================================================
[commercial metadata 8건의 정확한 의미]
==================================================

이전 보고의 "commercial meta 8건"은 다음을 뜻한다.

- 의미: ConceptSeed에 inline `commercial:` 필드를 직접 붙인 **seed 8개**
- 아님: 8개 메타데이터 필드 / 8개 variant / 8개 공통 template

해당 8 seed:
ai_second_career, ai_daily_assistant, ai_work_boost, online_income_start,
experience_productize, cashflow_retire, return_farm_guide, gov_support_scan

보완 후:
- `lib/data/concept_commercial_catalog.dart`의 bySeedId가 **전체 61 seed**에
  완전한 ConceptCommercialMeta를 제공한다.
- artifact variant(305)는 제목·설명만 유지하고, commercial 필드는 seed 공통
  metadata + track profile override로 조합한다 (305 복붙 없음).

==================================================
[coverage 표]
==================================================

항목                              | 수치
---------------------------------|------
ConceptSeed 전체                 | 61
artifact variant 전체            | 305
active (non-deprecated)          | 60
deprecated                       | 1 (policy_rural → return_farm_guide)
inactive                         | 0
commercial complete seed         | 61 / 61
inline commercial (레거시 8건)   | 8 (맵에도 미러링)
active × 지원 artifact 조합      | 300 (60×5)
추천 TOP50 meta 완전 (artifact별)| 50 / 50 이상
metadata 없는 active 추천 항목   | 0
간단입력 선택 시 WI 불가 항목    | 0 (사용자 확인 후)

artifact별 추천 가능(active+variant 존재, deprecated 제외):
- app: 60
- ebook: 60
- site: 60
- contents: 60
- promo_site: 60

==================================================
[변경 내역]
==================================================

추가:
- concept_commercial_catalog.dart (61 seed commercial 맵)
- catalog coverage / render manifest 테스트
- coverage_manifest.json, render_manifest.json (hash 기반)

수정:
- concept_recommendation_provider: deprecated 추천 제외, catalog resolve 사용
- commercial_studio_builder: candidateId→seedId 해석, catalog meta 사용
- project_design_engine: deprecated draft 선택 복원, confirm 시 catalog reasons 우선
- 추천·생성 경로는 RemoteDelivery 호출 없음

보존:
- seed/제목 삭제 없음
- policy_rural deprecated 유지 (draft 호환)
- dirty ops_golden_run_clean_reset.js 미변경

==================================================
[제목 전수검사]
==================================================

- 접미사 중복 (앱 앱 등): 0
- active 정확 중복 제목: 0
- 내부 ID 제목: 0
- policy_rural: 추천 목록에서 제외됨
- return_farm_guide: 대체 시드로 유지

==================================================
[전수 WI]
==================================================

- 검사 조합: 300
- PASS: 300
- FAIL: 0
- RemoteDelivery 호출: 0
