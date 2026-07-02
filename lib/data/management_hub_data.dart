class HubStatusItem {
  const HubStatusItem({
    required this.name,
    required this.progress,
    required this.status,
    required this.priority,
    required this.nextAction,
    this.tag,
  });

  final String name;
  final int progress;
  final String status;
  final String priority;
  final String nextAction;
  final String? tag;
}

class HubCheckPoint {
  const HubCheckPoint({
    required this.title,
    required this.detail,
    required this.area,
  });

  final String title;
  final String detail;
  final String area;
}

class AiDivisionBrief {
  const AiDivisionBrief({
    required this.divisionName,
    required this.currentStatus,
    required this.progressSummary,
    required this.revenueDirection,
    required this.growthDirection,
    required this.recommendedActions,
  });

  final String divisionName;
  final String currentStatus;
  final String progressSummary;
  final String revenueDirection;
  final String growthDirection;
  final List<String> recommendedActions;
}

class AiDepartmentBrief {
  const AiDepartmentBrief({
    required this.departmentName,
    required this.currentStatus,
    required this.keyProposal,
    required this.riskOrGap,
    required this.recommendedActions,
  });

  final String departmentName;
  final String currentStatus;
  final String keyProposal;
  final String riskOrGap;
  final List<String> recommendedActions;
}

class AiExecutionProposal {
  const AiExecutionProposal({
    required this.title,
    required this.description,
    required this.impact,
    required this.suggestedDecision,
  });

  final String title;
  final String description;
  final String impact;
  final String suggestedDecision;
}

class ManagementHubData {
  static const visionNote =
      '향후 AI대표는 각 부서·사업부 데이터를 종합해 '
      '「진행 / 보류 / 우선순위」를 사용자가 체크하고 실행 흐름으로 연결하는 '
      '의사결정 보조 허브로 확장됩니다.';

  static const divisionStatuses = <HubStatusItem>[
    HubStatusItem(
      name: '산업자동화 모니터링',
      progress: 72,
      status: 'B2B 제안·데모 자료 정리 중',
      priority: '높음',
      nextAction: 'SotongAutomationPromo 배포 확인',
      tag: '수익 연결',
    ),
    HubStatusItem(
      name: '앱개발',
      progress: 58,
      status: '6개 앱·프로모 URL 연결 완료',
      priority: '높음',
      nextAction: '소통여행 배포·소통사매앱 고도화',
      tag: '우선 처리',
    ),
    HubStatusItem(
      name: '유튜브/콘텐츠',
      progress: 35,
      status: '콘텐츠 방향 정리·업로드 일정 필요',
      priority: '중간',
      nextAction: '주간 콘텐츠 캘린더 확정',
      tag: '발전 가능',
    ),
    HubStatusItem(
      name: '전자책',
      progress: 28,
      status: '출간 주제·목차 후보 정리',
      priority: '중간',
      nextAction: '첫 전자책 MVP 주제 선정',
      tag: '발전 가능',
    ),
  ];

  static const departmentStatuses = <HubStatusItem>[
    HubStatusItem(
      name: '기획·아이디어',
      progress: 65,
      status: '우선순위·로드맵 정리 진행',
      priority: '높음',
      nextAction: '분기 실행 로드맵 확정',
    ),
    HubStatusItem(
      name: '홍보·마케팅',
      progress: 52,
      status: '4개 총괄·6개 앱 프로모 연결',
      priority: '높음',
      nextAction: 'Pages 404 점검·유입 전략 정리',
    ),
    HubStatusItem(
      name: '재무·세금',
      progress: 40,
      status: '재무 입력 구조·세무 점검 체계 구축',
      priority: '매우 높음',
      nextAction: '홈택스 연동 로드맵 초안',
      tag: '핵심',
    ),
    HubStatusItem(
      name: '온라인 고객대응',
      progress: 45,
      status: '문의·응대 흐름 샘플 설계',
      priority: '중간',
      nextAction: '응답 우선순위 템플릿 정리',
    ),
  ];

  static const checkPoints = <HubCheckPoint>[
    HubCheckPoint(
      area: '앱개발',
      title: '소통여행 APK → 프로모 연결',
      detail: '배포 흐름이 끊기지 않도록 다운로드·안내 페이지 점검',
    ),
    HubCheckPoint(
      area: '홍보',
      title: 'PUBLIC 4개 총괄 Pages 확인',
      detail: 'Automation·Apps·Contents·Ebook 배포 404 여부',
    ),
    HubCheckPoint(
      area: '재무',
      title: '월간 매출·비용 입력 루틴',
      detail: '재무·세금 본부에서 샘플 데이터 정기 점검',
    ),
    HubCheckPoint(
      area: '산업자동화',
      title: 'B2B 제안서·포트폴리오',
      detail: '제조 고객 대상 핵심 경험 중심 자료 정리',
    ),
  ];

  static const priorityItems = <String>[
    '소통여행 배포·프로모 완성',
    '재무·세금 본부 홈택스 연동 로드맵',
    'PUBLIC 홍보사이트 Pages 배포 확인',
    '소통사매앱 지역 데이터 구조 고도화',
  ];

  static const revenueItems = <String>[
    '산업자동화 B2B 프로젝트 제안',
    '앱 Play Store·프로모 유입',
    '전자책·스마트스토어 판매 연결',
    '콘텐츠·앱 홍보 영상 교차 수익',
  ];

  static const growthItems = <String>[
    'AI대표 의사결정 체크 → 실행 연동',
    '6개 앱 포트폴리오 통합 홍보',
    '지역 밀착형 앱(소통사매) 확장',
    '홈택스·재무 자동 리포트',
  ];

  static const nextActions = <String>[
    '오늘: PUBLIC Pages 404 점검',
    '이번 주: 소통여행 배포 흐름 완성',
    '이번 달: 재무·세금 점검 루틴 확립',
    '다음 분기: AI대표 실행 승인 UI 프로토타입',
  ];

  static const aiTodayBriefing = '''
소통웨어 전체 사업은 「앱 배포·홍보 연결·재무 기반」 3축에서 동시에 움직여야 합니다.
단기 수익은 산업자동화 B2B와 소통여행 배포, 중기 성장은 6개 앱 포트폴리오와 콘텐츠,
장기 경쟁력은 재무·세금 본부의 홈택스 연동과 AI대표 의사결정 체계입니다.''';

  static const divisionBriefs = <AiDivisionBrief>[
    AiDivisionBrief(
      divisionName: '산업자동화',
      currentStatus: '핵심 경험 보유, B2B 홍보 강화 단계',
      progressSummary: '제안서·데모·Promo 연결 진행',
      revenueDirection: '제조 현장 모니터링 구축·유지보수',
      growthDirection: '바코드·PLC·MES 통합 패키지화',
      recommendedActions: ['제안서 목차 확정', 'Promo 404 확인', '데모 시나리오 1건'],
    ),
    AiDivisionBrief(
      divisionName: '앱개발',
      currentStatus: '6개 앱·6개 프로모 URL 내부 연결',
      progressSummary: '소통여행 배포·소통사매 고도화가 핵심',
      revenueDirection: 'Play Store·프로모 유입·APK 배포',
      growthDirection: '앱 포트폴리오 + AI 기능 확장',
      recommendedActions: ['소통여행 배포', '사매앱 카테고리 정리', 'Pages 점검'],
    ),
    AiDivisionBrief(
      divisionName: '유튜브/콘텐츠',
      currentStatus: '방향 정리 완료, 업로드 일정 미정',
      progressSummary: '지역·시골·앱 홍보 콘텐츠 교차',
      revenueDirection: '채널 수익·앱·전자책 연계',
      growthDirection: 'AI 음악·쇼츠·브이로그 시리즈',
      recommendedActions: ['주 1회 업로드 목표', '첫 3편 주제', 'Promo 연동'],
    ),
    AiDivisionBrief(
      divisionName: '전자책',
      currentStatus: '주제 후보 다수, 출간 MVP 선정 필요',
      progressSummary: '경험·기술·농촌·자동화 노하우 정리',
      revenueDirection: '전자책·스마트스토어·크몽',
      growthDirection: '시리즈 출간·앱·콘텐츠 연계',
      recommendedActions: ['첫 출간 주제 1건', '목차 초안', '판매 채널 연결'],
    ),
  ];

  static const departmentBriefs = <AiDepartmentBrief>[
    AiDepartmentBrief(
      departmentName: '기획·아이디어',
      currentStatus: '사업·프로젝트 우선순위 정리 진행',
      keyProposal: '분기 로드맵·신규 아이디어·성장 전략 통합',
      riskOrGap: '우선순위 미확정 시 리소스 분산',
      recommendedActions: ['로드맵 확정', '신규 아이디어 3건', '성장 시나리오'],
    ),
    AiDepartmentBrief(
      departmentName: '홍보·마케팅',
      currentStatus: '총괄·개별 프로모 URL 연결',
      keyProposal: '웹·앱·콘텐츠·전자책 통합 브랜딩',
      riskOrGap: 'Pages 미배포 시 404로 유입 손실',
      recommendedActions: ['404 점검', '카카오 공유 문구', '채널별 일정'],
    ),
    AiDepartmentBrief(
      departmentName: '재무·세금',
      currentStatus: '재무 입력·세무 점검 체계 구축 중',
      keyProposal: '홈택스 연동·자금 흐름·절세·재테크 AI 보조',
      riskOrGap: '세무·비용 누락 시 성장 리스크',
      recommendedActions: ['월간 재무 루틴', '홈택스 로드맵', '투자·재테크 점검'],
    ),
    AiDepartmentBrief(
      departmentName: '온라인 고객대응',
      currentStatus: '문의·응대 흐름 샘플 설계',
      keyProposal: '고객 니즈·우선순위·AI 응대 보조',
      riskOrGap: '응대 지연 시 신뢰도 하락',
      recommendedActions: ['FAQ 템플릿', '응답 SLA', '반복 질문 정리'],
    ),
  ];

  static const executionProposals = <AiExecutionProposal>[
    AiExecutionProposal(
      title: '소통여행 배포 우선 실행',
      description: 'APK·프로모·설치 안내를 한 흐름으로 연결',
      impact: '단기 수익·실적 가시화',
      suggestedDecision: '진행 권장',
    ),
    AiExecutionProposal(
      title: '재무·세금 본부 홈택스 로드맵 착수',
      description: '세무 점검·재무 리포트 자동화 방향 문서화',
      impact: '장기 기업 성장 기반',
      suggestedDecision: '우선 검토',
    ),
    AiExecutionProposal(
      title: 'PUBLIC Pages 일괄 404 점검',
      description: '4개 총괄·6개 앱 프로모 배포 상태 확인',
      impact: '홍보 유입·브랜드 신뢰',
      suggestedDecision: '오늘 실행',
    ),
  ];
}
