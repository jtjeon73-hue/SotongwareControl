import '../models/artifact_type.dart';
import '../services/business_planning_service.dart';

/// 제작 단계 정의 (UI·데모 enrichment용). Firestore stageId와 매칭한다.
class Sotong24WorkflowStageDef {
  const Sotong24WorkflowStageDef({
    required this.id,
    required this.order,
    required this.name,
    required this.purpose,
    required this.workDescription,
    required this.aiWork,
    required this.outputs,
    required this.qualityChecks,
    required this.userChecks,
    required this.nextHint,
    this.approvalTypicallyRequired = false,
  });

  final String id;
  final int order;
  final String name;
  final String purpose;
  final String workDescription;
  final String aiWork;
  final String outputs;
  final List<String> qualityChecks;
  final List<String> userChecks;
  final String nextHint;
  final bool approvalTypicallyRequired;
}

class Sotong24WorkflowDef {
  const Sotong24WorkflowDef({
    required this.productType,
    required this.title,
    required this.summary,
    required this.stages,
    this.contentSubtype = '',
  });

  final String productType;
  final String contentSubtype;
  final String title;
  final String summary;
  final List<Sotong24WorkflowStageDef> stages;

  int get totalStages => stages.length;

  Sotong24WorkflowStageDef? byId(String id) {
    for (final s in stages) {
      if (s.id == id) return s;
    }
    return null;
  }

  Sotong24WorkflowStageDef? byOrder(int order) {
    for (final s in stages) {
      if (s.order == order) return s;
    }
    return null;
  }
}

class Sotong24WorkflowCatalog {
  Sotong24WorkflowCatalog._();

  static Sotong24WorkflowDef forProduct(
    String productType, {
    String contentSubtype = '',
  }) {
    final primary = ArtifactType.normalize(productType);
    switch (primary) {
      case ArtifactType.ebook:
        return ebook;
      case ArtifactType.app:
        return app;
      case ArtifactType.site:
        return site;
      case ArtifactType.promoSite:
        return promoSite;
      case ArtifactType.contents:
        return contentsFor(contentSubtype);
      default:
        return ebook;
    }
  }

  /// 전자책 — BusinessPlanningService.standardWorkflowTitles 18단계와 ID 일치.
  static final ebook = Sotong24WorkflowDef(
    productType: ArtifactType.ebook,
    title: '전자책 제작',
    summary: 'Sotong24Work 표준 18단계 전자책 워크플로',
    stages: [
      for (
        var i = 0;
        i < BusinessPlanningService.standardWorkflowTitles.length;
        i++
      )
        _ebookStage(
          BusinessPlanningService.standardWorkflowTitles[i].$1,
          BusinessPlanningService.standardWorkflowTitles[i].$2,
          i + 1,
        ),
    ],
  );

  static Sotong24WorkflowStageDef _ebookStage(
    String id,
    String name,
    int order,
  ) {
    final meta =
        _ebookMeta[id] ??
        (
          purpose: '$name 단계를 수행합니다.',
          work: '단계 작업을 진행합니다.',
          ai: 'AI/Cursor가 초안·검사를 지원합니다.',
          outputs: '단계 산출물',
          quality: const <String>['기본 품질 확인'],
          user: const <String>['결과 확인'],
          next: '다음 단계로 진행',
          approval: order == 9 || order >= 12,
        );
    return Sotong24WorkflowStageDef(
      id: id,
      order: order,
      name: name,
      purpose: meta.purpose,
      workDescription: meta.work,
      aiWork: meta.ai,
      outputs: meta.outputs,
      qualityChecks: meta.quality,
      userChecks: meta.user,
      nextHint: meta.next,
      approvalTypicallyRequired: meta.approval,
    );
  }

  static final _ebookMeta =
      <
        String,
        ({
          String purpose,
          String work,
          String ai,
          String outputs,
          List<String> quality,
          List<String> user,
          String next,
          bool approval,
        })
      >{
        'idea_clarify': (
          purpose: '전자책으로 풀 문제·독자·결과물을 한 문장으로 고정한다.',
          work: '주제·독자·약속 결과를 정리한다.',
          ai: '컨셉·제목 후보와 독자 페르소나 초안을 제안한다.',
          outputs: '아이디어 한 장 요약',
          quality: ['독자가 명확한가', '결과물이 전자책으로 적합한가'],
          user: ['주제 확정', '독자 확정'],
          next: '고객 문제 검증',
          approval: false,
        ),
        'problem_validate': (
          purpose: '독자가 실제로 겪는 문제인지 검증한다.',
          work: '직접 인터뷰 여부를 명시하고 공개 고객 목소리·문제 신호·대안을 검증한다.',
          ai: '검증 가능한 공개 원문을 조사해 출처·신호·가설·포지셔닝을 연결한다.',
          outputs: '출처 연결 문제 검증 메모',
          quality: ['공개 출처 5개·독립 도메인 3개', '출처 연결 신호 10건', 'P01/P02·H1~H5·포지셔닝'],
          user: ['문제 문장 승인'],
          next: '자료 준비',
          approval: false,
        ),
        'materials_prep': (
          purpose: '집필에 필요한 자료·사례·출처를 모은다.',
          work: '참고 자료·금지 사항·출처 목록을 준비한다.',
          ai: '자료 목록·조사 프롬프트를 생성한다.',
          outputs: '자료 폴더/목록',
          quality: ['출처 추적 가능', '저작권 주의 표시'],
          user: ['자료 범위 확인'],
          next: '기획',
          approval: false,
        ),
        'planning': (
          purpose: '목차·분량·톤·수익 포인트를 확정한다.',
          work: '목차와 장별 목표를 작성한다.',
          ai: '목차·챕터 요약·분량 가이드를 제안한다.',
          outputs: '기획안·목차',
          quality: ['목차 일관성', '독자 여정'],
          user: ['목차 확정'],
          next: '프로젝트 설정',
          approval: true,
        ),
        'project_setup': (
          purpose: 'Sotong24Work/로컬 프로젝트 구조를 준비한다.',
          work: '폴더·버전·파일 규칙을 설정한다.',
          ai: '프로젝트 체크리스트를 생성한다.',
          outputs: '프로젝트 골격',
          quality: ['경로·이름 규칙'],
          user: ['프로젝트 확인'],
          next: 'AI 프롬프트 생성',
          approval: false,
        ),
        'prompt_generate': (
          purpose: '장별 집필·편집에 쓸 작업 프롬프트를 만든다.',
          work: '프롬프트 템플릿을 확정한다.',
          ai: '장별 프롬프트 초안을 작성한다.',
          outputs: '프롬프트 세트',
          quality: ['지시 명확성', '금지 규칙 포함'],
          user: ['프롬프트 검토'],
          next: '초안 제작',
          approval: false,
        ),
        'draft': (
          purpose: '본문 초안을 작성한다.',
          work: '장별 초안을 생성·정리한다.',
          ai: '초안 집필·문장 다듬기를 수행한다.',
          outputs: '본문 초안',
          quality: ['장 누락 없음', '예시 포함'],
          user: ['초안 훑어보기'],
          next: '실행/기능 검사(해당 시) 또는 사용자 확인',
          approval: false,
        ),
        'build_test': (
          purpose: '전자책에서는 보통 생략·경량 검사로 둔다.',
          work: '파일 열림·형식 확인.',
          ai: '형식 오류를 점검한다.',
          outputs: '검사 로그',
          quality: ['파일 손상 없음'],
          user: ['필요 시 확인'],
          next: '사용자 확인',
          approval: false,
        ),
        'user_review': (
          purpose: '사용자가 초안 방향·톤·사례를 확인한다.',
          work: '핵심 장·표지 후보를 검토한다.',
          ai: '검토 포인트 체크리스트를 제시한다.',
          outputs: '검토 메모',
          quality: ['독자 가치', '과장 표현 여부'],
          user: ['방향 승인 또는 보완 요청'],
          next: '보완 수정',
          approval: true,
        ),
        'revise': (
          purpose: '피드백을 반영해 본문을 고친다.',
          work: '수정·추가·삭제.',
          ai: '보완 지시문에 따라 재작성한다.',
          outputs: '수정본',
          quality: ['피드백 반영률'],
          user: ['수정 결과 확인'],
          next: '품질 검사',
          approval: false,
        ),
        'quality': (
          purpose: '맞춤법·구조·사실·출처를 검사한다.',
          work: '품질 체크리스트 실행.',
          ai: '품질·출처 검사를 수행한다.',
          outputs: '품질 리포트',
          quality: ['오탈자', '출처', '금칙어'],
          user: ['품질 리포트 확인'],
          next: '등록 준비',
          approval: false,
        ),
        'publish_prep': (
          purpose: '판매/배포용 메타·미리보기를 준비한다.',
          work: '제목·설명·가격·미리보기 정리.',
          ai: '상품 설명·키워드 초안을 만든다.',
          outputs: '등록 패키지 초안',
          quality: ['제목·가격·설명 완비'],
          user: ['제목', '가격', '상품 설명', '미리보기', '저작권/출처'],
          next: '배포(해당 시) 또는 홍보자료',
          approval: true,
        ),
        'deploy': (
          purpose: '전자책은 채널 업로드 직전 점검에 가깝다.',
          work: '최종 파일·링크 확인.',
          ai: '배포 체크리스트를 생성한다.',
          outputs: '배포 준비 상태',
          quality: ['최종 파일 버전'],
          user: ['배포 승인(수동)'],
          next: '홍보자료 제작',
          approval: true,
        ),
        'promo': (
          purpose: '홍보용 짧은 소개·쇼츠 소재를 만든다.',
          work: '홍보 문구·썸네일 문구.',
          ai: '홍보 카피 초안을 작성한다.',
          outputs: '홍보 초안',
          quality: ['메시지 일관성'],
          user: ['홍보 문구 확인'],
          next: '공개 및 공유',
          approval: false,
        ),
        'launch': (
          purpose: '공개·공유 시점을 확정한다.',
          work: '공개 체크.',
          ai: '공개 안내문을 초안한다.',
          outputs: '공개 기록',
          quality: ['채널·권한'],
          user: ['공개 승인(수동)'],
          next: '성과 확인',
          approval: true,
        ),
        'measure': (
          purpose: '초기 반응·판매·문의를 기록한다.',
          work: '지표 메모.',
          ai: '측정 항목을 제안한다.',
          outputs: '성과 메모',
          quality: ['측정 가능 지표'],
          user: ['지표 확인'],
          next: '재보완',
          approval: false,
        ),
        'iterate': (
          purpose: '피드백으로 개정판·추가 장을 계획한다.',
          work: '개선 백로그.',
          ai: '개선 아이디어를 정리한다.',
          outputs: '개선 목록',
          quality: ['우선순위'],
          user: ['다음 개선 선택'],
          next: '유지관리',
          approval: false,
        ),
        'maintain': (
          purpose: '버전·백업·문의 대응을 유지한다.',
          work: '유지보수 체크.',
          ai: '유지 체크리스트를 갱신한다.',
          outputs: '유지 로그',
          quality: ['백업 존재'],
          user: ['유지 주기 확인'],
          next: '종료 또는 다음 제품',
          approval: false,
        ),
      };

  static final app = Sotong24WorkflowDef(
    productType: ArtifactType.app,
    title: '앱 제작',
    summary: 'Android APK 제작 완료와 출시 전 검토까지의 18단계 Production Workflow',
    stages: _numbered(
      [
        ('app_idea', '앱 아이디어 정리', '문제·핵심 가치·대상 사용자·한 줄 정의를 만든다.'),
        ('app_problem_validate', '고객 문제 검증', '필요성·대체수단·경쟁 앱을 검토한다.'),
        ('app_market_analysis', '시장·경쟁 분석', '유사 앱·차별점·수익 가능성·위험을 정리한다.'),
        ('app_requirements', '제품 요구사항 정의', 'MVP·제외 기능·성공 기준을 고정한다.'),
        (
          'app_project_setup',
          '프로젝트 셋업',
          '독립 저장소에 실제 Android Flutter 프로젝트를 생성·검증한다.',
        ),
        ('app_ux_flow', 'UX 흐름 설계', '주요 화면·전환·사용자 흐름을 설계한다.'),
        ('app_design_system', 'UI 디자인 시스템', '색상·타이포그래피·공통 컴포넌트를 정의한다.'),
        ('app_data_state', '데이터·상태 구조 설계', '모델·상태관리·데이터·Firebase 필요성을 결정한다.'),
        ('app_core_implementation_1', '핵심 기능 구현 1', 'MVP 핵심 기능 첫 묶음을 구현한다.'),
        ('app_core_implementation_2', '핵심 기능 구현 2', '나머지 MVP 기능과 화면 흐름을 구현한다.'),
        (
          'app_integration_errors',
          '통합 및 예외처리',
          'loading/error/empty/offline을 포함해 통합한다.',
        ),
        ('app_code_quality', '코드 품질 점검', 'flutter analyze·lint·구조·보안을 점검한다.'),
        (
          'app_automated_tests',
          '자동 테스트',
          'unit/widget/integration 가능한 테스트를 실행한다.',
        ),
        (
          'app_android_release',
          'Android Release Build',
          '설치 가능한 release APK를 빌드·검증한다.',
        ),
        ('app_device_review_prep', '실기기 검증 준비', 'APK·설치 안내·권한·체크리스트를 준비한다.'),
        ('app_user_review_package', '사용자 검토 패키지', '휴대폰 다운로드·설치·확인 결과물을 준비한다.'),
        ('app_revision_quality', '보완·최종 품질 검증', '보완 요청과 최종 regression을 처리한다.'),
        (
          'app_production_complete',
          'Production Complete',
          '최종 APK·소스·테스트·설치·출시 준비자료를 확정한다.',
        ),
      ],
      approvalIds: {
        'app_requirements',
        'app_user_review_package',
        'app_revision_quality',
      },
    ),
  );

  static final industrial = Sotong24WorkflowDef(
    productType: 'industrial',
    title: '산업자동화 SW',
    summary: '현장 요구부터 시운전·납품·유지보수까지',
    stages: _numbered(
      [
        ('ind_req', '고객/현장 요구사항', '현장 문제와 목표를 수집한다.'),
        ('ind_process', '설비/공정 분석', '공정·택트·병목을 파악한다.'),
        ('ind_plc', 'PLC/장비 구성 확인', '제어기·장비 구성을 확인한다.'),
        ('ind_comm', '통신 사양', '프로토콜·네트워크를 정의한다.'),
        ('ind_io', 'I/O 및 데이터 정의', '신호·태그·데이터 모델을 정한다.'),
        ('ind_scenario', '작업 시나리오', '정상/이상 시나리오를 작성한다.'),
        ('ind_arch', '프로그램 구조 설계', '모듈·상태머신 구조를 설계한다.'),
        ('ind_hmi', 'UI/HMI/모니터링 설계', '모니터링·조작 화면을 설계한다.'),
        ('ind_iface', 'PLC/MES/조립툴 인터페이스', '상위·현장 인터페이스를 정의한다.'),
        ('ind_vision', '비전검사 연동', '비전/검사 연동을 설계한다.'),
        ('ind_collect', '데이터 수집', '로그·실적 수집을 구현한다.'),
        ('ind_alarm', '알람/로그', '알람·이력 체계를 만든다.'),
        ('ind_dev', '개발', '제어·연동 소프트웨어를 구현한다.'),
        ('ind_sim', '시뮬레이션', '오프라인/시뮬로 검증한다.'),
        ('ind_eq_test', '장비 연동 테스트', '실장비 연동을 시험한다.'),
        ('ind_safety', '예외/안전 처리', '안전·인터록을 점검한다.'),
        ('ind_sat', '현장 시운전', '현장에서 시운전한다.'),
        ('ind_accept', '사용자 검수', '고객 검수·승인을 받는다.'),
        ('ind_backup', '백업', '프로그램·설정을 백업한다.'),
        ('ind_manual', '매뉴얼', '운전·유지 매뉴얼을 작성한다.'),
        ('ind_delivery', '납품', '납품·인수인계를 진행한다.'),
        ('ind_maint', '유지보수', '개선·장애 대응을 한다.'),
      ],
      approvalIds: {'ind_accept', 'ind_delivery'},
    ),
  );

  static final site = Sotong24WorkflowDef(
    productType: ArtifactType.site,
    title: '사이트 제작',
    summary:
        'Sotong24Work SiteStageContract 18단계 (배포 실행은 사용자 승인 후). '
        '콘텐츠 업데이트·방문자 분석·수익화는 출시 후 운영으로 Production WI 18단계 밖이다.',
    stages: [
      for (var i = 0; i < BusinessPlanningService.siteWorkflowStages.length; i++)
        _siteStage(
          BusinessPlanningService.siteWorkflowStages[i].$1,
          BusinessPlanningService.siteWorkflowStages[i].$2,
          BusinessPlanningService.siteWorkflowStages[i].$3,
          i + 1,
        ),
    ],
  );

  static final promoSite = Sotong24WorkflowDef(
    productType: ArtifactType.promoSite,
    title: '마케팅사이트 제작',
    summary:
        'SiteStageContract 18단계와 동일 트랙(marketing_site). '
        '배포·외부 공개는 사용자 승인 gate 이후에만 진행한다.',
    stages: site.stages,
  );

  static Sotong24WorkflowStageDef _siteStage(
    String id,
    String name,
    String purpose,
    int order,
  ) {
    final approval =
        id == 'site_user_review' ||
        id == 'site_revision_quality' ||
        id == 'site_launch_package' ||
        id == 'site_deploy_release';
    return Sotong24WorkflowStageDef(
      id: id,
      order: order,
      name: name,
      purpose: purpose,
      workDescription: purpose,
      aiWork: '단계 산출물·검증 증거를 작성한다.',
      outputs: name,
      qualityChecks: const ['계약 산출물', '증거', '과장 금지'],
      userChecks: approval ? const ['사용자 확인/승인'] : const ['단계 확인'],
      nextHint: order >= 18 ? 'Production Complete / 출시 후 운영' : '다음 단계',
      approvalTypicallyRequired: approval,
    );
  }

  static Sotong24WorkflowDef contentsFor(String subtype) {
    final label = ContentSubtype.labelKo(subtype);
    return Sotong24WorkflowDef(
      productType: ArtifactType.contents,
      contentSubtype: subtype,
      title: '콘텐츠 제작${subtype.isEmpty ? '' : ' · $label'}',
      summary: '트렌드부터 업로드·분석까지 (유형별 확장 가능)',
      stages: _numbered(
        [
          ('cnt_trend', '트렌드 탐색', '주제 후보와 유행을 본다.'),
          ('cnt_topic', '주제 선정', '이번 콘텐츠 주제를 고른다.'),
          ('cnt_target', '타깃', '시청/청취 대상을 정한다.'),
          ('cnt_plan', '콘텐츠 기획', '구성·분량을 기획한다.'),
          ('cnt_research', '자료조사', '사실·레퍼런스를 모은다.'),
          ('cnt_script', '대본/가사', '대본 또는 가사를 작성한다.'),
          ('cnt_rights', '저작권 점검', '사용 가능 여부를 점검한다.'),
          ('cnt_produce', '제작', '음원/영상 초안을 만든다.'),
          ('cnt_ai_review', 'AI 생성물 검토', 'AI 산출물을 사람이 검토한다.'),
          ('cnt_edit', '음원/영상 편집', '편집·믹싱을 한다.'),
          ('cnt_thumb', '썸네일', '썸네일·커버를 만든다.'),
          ('cnt_meta', '제목/설명/태그', '메타데이터를 작성한다.'),
          ('cnt_qa', '최종 품질검사', '완성도를 검사한다.'),
          ('cnt_policy', '플랫폼 정책검사', '업로드 정책을 점검한다.'),
          ('cnt_upload_prep', '업로드 준비', '파일·일정을 준비한다.'),
          ('cnt_approve', '사용자 승인', '업로드 전 승인한다.'),
          ('cnt_upload', '업로드', '플랫폼 업로드는 수동.'),
          ('cnt_promo', '홍보', '공유·홍보한다.'),
          ('cnt_analytics', '조회/반응 분석', '반응을 분석한다.'),
          ('cnt_next', '후속 콘텐츠 기획', '다음 편을 기획한다.'),
        ],
        approvalIds: {'cnt_approve', 'cnt_upload'},
      ),
    );
  }

  static List<Sotong24WorkflowStageDef> _numbered(
    List<(String, String, String)> rows, {
    Set<String> approvalIds = const {},
  }) {
    return [
      for (var i = 0; i < rows.length; i++)
        Sotong24WorkflowStageDef(
          id: rows[i].$1,
          order: i + 1,
          name: rows[i].$2,
          purpose: rows[i].$3,
          workDescription: '${rows[i].$2} 작업을 수행합니다.',
          aiWork: 'AI가 초안·체크리스트·초안 산출물을 지원합니다.',
          outputs: '${rows[i].$2} 산출물',
          qualityChecks: const ['완성도', '일관성'],
          userChecks: const ['결과 확인'],
          nextHint: i + 1 < rows.length ? rows[i + 1].$2 : '워크플로 완료',
          approvalTypicallyRequired: approvalIds.contains(rows[i].$1),
        ),
    ];
  }

  /// 산업자동화는 ArtifactType 밖이므로 별도 키로도 조회.
  static Sotong24WorkflowDef resolve({
    required String productType,
    String contentSubtype = '',
    String? businessUnitHint,
  }) {
    if (businessUnitHint == 'industrial' ||
        productType == 'industrial' ||
        productType.contains('산업')) {
      return industrial;
    }
    return forProduct(productType, contentSubtype: contentSubtype);
  }
}
