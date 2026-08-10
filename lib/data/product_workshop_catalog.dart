/// 제품제작 공작실 — 로컬 단계/상태 카탈로그 (실시간 연동 전).
class ProductionStep {
  const ProductionStep({
    required this.number,
    required this.name,
    required this.purpose,
    required this.inputs,
    required this.aiWork,
    required this.outputs,
    required this.review,
    required this.approval,
    required this.nextStep,
    required this.automationLevel,
  });

  final int number;
  final String name;
  final String purpose;
  final String inputs;
  final String aiWork;
  final String outputs;
  final String review;
  final String approval;
  final String nextStep;
  final String automationLevel;
}

class ArtifactProductionPlaybook {
  const ArtifactProductionPlaybook({
    required this.id,
    required this.title,
    required this.steps,
    this.notes = '',
  });

  final String id;
  final String title;
  final List<ProductionStep> steps;
  final String notes;
}

class Sotong24WorkStatusCatalog {
  Sotong24WorkStatusCatalog._();

  static const supportedArtifacts = [
    '전자책 (진행 중)',
    '앱 (골격)',
    '지식사이트 (골격)',
    '마케팅사이트 (골격)',
    '컨텐츠 (골격)',
  ];

  static const automationLevel = '부분 자동화 — 작업지시·DevWorkDoc·Inbox 연결 중심';
  static const completed = [
    'Instruction Contract 1.1',
    'Project Design Engine',
    'Planning Library 관리',
    'DevWorkDoc Active/Versions',
    'Sotong24Work Inbox 전달',
  ];
  static const partial = ['전자책 다단계 제작 파이프라인', 'checksum·버전 복구'];
  static const upcoming = [
    'artifact별 전문가급 제작 단계 자동화',
    '검수·승인 UI 연동',
    '출시·홍보·판매 이벤트 연결',
  ];
  static const versionNote = '로컬 상태 요약 (실시간 API 미연결)';
}

class ProductLifecycle {
  static const stages = [
    '아이디어',
    '기획',
    '작업지시',
    '제작',
    '검수',
    '승인',
    '등록',
    '출시',
    '홍보',
    '판매',
    '수익',
    '개선',
    '세금 관리',
    '유지관리',
  ];
}

class ProductWorkshopCatalog {
  ProductWorkshopCatalog._();

  static final playbooks = <ArtifactProductionPlaybook>[
    ArtifactProductionPlaybook(
      id: 'ebook',
      title: '전자책',
      notes: '현재 실제 워크플로를 반영한 단계입니다.',
      steps: [
        ProductionStep(
          number: 1,
          name: '결과물·고객 확정',
          purpose: '전자책 대상과 고객을 고정',
          inputs: '주제, 고객, 문제',
          aiWork: '컨셉 TOP10·카테고리 추천',
          outputs: '확정 컨셉',
          review: '사용자 컨셉 확정',
          approval: '사용자',
          nextStep: '세부 기획',
          automationLevel: '높음 (PDE)',
        ),
        ProductionStep(
          number: 2,
          name: '세부 기획·제작 정보',
          purpose: '목차·분량·톤 확정',
          inputs: '확정 컨셉',
          aiWork: '기획 문장·사양 초안',
          outputs: '기획안',
          review: 'AI 검토 리포트',
          approval: '사용자 최종 확정',
          nextStep: 'Contract/작업지시',
          automationLevel: '높음',
        ),
        ProductionStep(
          number: 3,
          name: '작업지시서 생성',
          purpose: 'Contract 1.1 작업지시',
          inputs: '확정 기획',
          aiWork: 'Instruction JSON·검증',
          outputs: '작업지시 JSON',
          review: 'VALID/WARNING/BLOCKED',
          approval: '사용자 전달 승인',
          nextStep: 'DevWorkDoc/Inbox',
          automationLevel: '높음',
        ),
        ProductionStep(
          number: 4,
          name: '소통24워크 제작',
          purpose: '본문·표지·PDF 제작',
          inputs: 'Inbox 작업지시',
          aiWork: '단계별 집필·편집 (Sotong24Work)',
          outputs: '초안·산출물',
          review: '단계 검수',
          approval: '사용자 단계 승인',
          nextStep: '등록·출시',
          automationLevel: '부분',
        ),
        ProductionStep(
          number: 5,
          name: '등록·홍보·판매',
          purpose: '상품화 이후 운영',
          inputs: '완성본',
          aiWork: '채널별 메시지 초안(향후)',
          outputs: '판매·홍보 자산',
          review: '채널 검수',
          approval: '사용자',
          nextStep: '수익·개선',
          automationLevel: '낮음(설계)',
        ),
      ],
    ),
    ArtifactProductionPlaybook(
      id: 'app',
      title: '앱',
      notes: '골격 — 향후 전문가급 단계로 확장.',
      steps: _skeletonSteps('앱', 'Flutter/Firebase 사양'),
    ),
    ArtifactProductionPlaybook(
      id: 'site',
      title: '지식사이트',
      notes: '골격 — IA·콘텐츠·SEO 단계 확장 예정.',
      steps: _skeletonSteps('지식사이트', '정보구조·콘텐츠'),
    ),
    ArtifactProductionPlaybook(
      id: 'promo_site',
      title: '마케팅사이트',
      notes: '골격 — 랜딩·CTA·전환 단계 확장 예정.',
      steps: _skeletonSteps('마케팅사이트', '랜딩·카피'),
    ),
    ArtifactProductionPlaybook(
      id: 'contents',
      title: '컨텐츠',
      notes: '골격 — 쇼츠·영상·음원 단계 확장 예정.',
      steps: _skeletonSteps('컨텐츠', '스크립트·미디어'),
    ),
  ];

  static List<ProductionStep> _skeletonSteps(String name, String spec) {
    return [
      ProductionStep(
        number: 1,
        name: '$name 기획',
        purpose: '목표·고객 확정',
        inputs: '아이디어·고객',
        aiWork: '컨셉·사양 초안',
        outputs: '기획안',
        review: '사용자',
        approval: '사용자',
        nextStep: '작업지시',
        automationLevel: '설계',
      ),
      ProductionStep(
        number: 2,
        name: '작업지시',
        purpose: 'Contract 기반 지시',
        inputs: '기획안',
        aiWork: 'Instruction 생성',
        outputs: '작업지시 JSON',
        review: '검증',
        approval: '사용자',
        nextStep: '제작',
        automationLevel: '부분(엔진 공유)',
      ),
      ProductionStep(
        number: 3,
        name: '제작·검수',
        purpose: spec,
        inputs: '작업지시',
        aiWork: 'Sotong24Work 제작(예정)',
        outputs: '산출물',
        review: '검수 체크리스트',
        approval: '사용자',
        nextStep: '출시',
        automationLevel: '낮음',
      ),
    ];
  }
}
