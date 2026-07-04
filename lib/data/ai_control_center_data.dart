import '../models/ai_control_center.dart';

class AiControlCenterData {
  static const lastAutoCheckTime = '오늘 06:10';
  static const nextAutoCheckTime = '오늘 07:00';
  static const systemMode = '24시간 AI 경영 관제 모드';
  static const automaticReportQueue = 7;
  static const notificationQueue = 10;
  static const approvalRequiredCount = 5;
  static const completedTodayCount = 18;
  static const warningCount = 3;

  static const revenueSummary = RevenueSummary(
    todayRevenue: '₩428,000',
    orderCount: 9,
    topSource: '전자책 사전문의 · 앱 다운로드 유입',
    forecast: '소통AI여행 홍보 영상 공개 시 추가 전환 가능',
  );

  static const downloadSummary = DownloadSummary(
    todayDownloads: 43,
    mostDownloaded: '소통AI여행 APK 안내 자료',
    conversionSignal: '다운로드 후 문의 전환 6건 감지',
    trend: '전일 대비 +18%',
  );

  static const customerInquirySummary = CustomerInquirySummary(
    unansweredCount: 6,
    urgentCount: 2,
    topCategory: '앱 기능 / 스마트스토어 / 자동화 견적 문의',
    summary: 'AI홍보.마케팅부가 응대·정리 후 AI전략부·기획부에 피드백 전달',
  );

  static const officeCards = <AiOfficeDashboardCard>[
    AiOfficeDashboardCard(
      title: '오늘의 대표 브리핑',
      value: '사업 전환점 점검',
      summary: '앱개발·전자책·홍보가 동시에 움직이고 있어 우선순위 승인과 실행 순서 확정이 필요합니다.',
      status: AiSystemStatus.automaticReportPending,
      department: 'AI대표',
    ),
    AiOfficeDashboardCard(
      title: '상품 등록·유지보수',
      value: '등록 5 · 점검 5',
      summary: '견적도우미 검수 중, 소통AI여행 v0.3 유지보수 예정. 등록 파이프라인 4건 진행.',
      status: AiSystemStatus.monitoring,
      department: 'AI상품개발부',
    ),
    AiOfficeDashboardCard(
      title: '긴급 알림',
      value: '3건',
      summary: '다운로드센터 경로 점검, 고객 문의 지연, 광고비 증액 승인 요청이 감지되었습니다.',
      status: AiSystemStatus.warning,
      department: 'AI지시진행부',
    ),
    AiOfficeDashboardCard(
      title: '승인 대기 업무',
      value: '5건',
      summary: '일본 여행 기능 우선 개발, 전자책 신규 등록, 광고비 증액 등 대표 판단이 필요합니다.',
      status: AiSystemStatus.approvalRequired,
      department: 'AI대표',
    ),
    AiOfficeDashboardCard(
      title: '오늘의 매출 요약',
      value: '₩428,000',
      summary: '소액 결제와 B2B 상담 예약이 발생했습니다. 매출 출처 추적 구조는 더미데이터 상태입니다.',
      status: AiSystemStatus.completed,
      department: 'AI세무회계부',
    ),
    AiOfficeDashboardCard(
      title: '다운로드 발생 현황',
      value: '43회',
      summary: '소통AI여행 안내 자료 다운로드가 가장 많고, 전환 문의가 함께 늘었습니다.',
      status: AiSystemStatus.notificationPending,
      department: 'AI홍보.마케팅부',
    ),
    AiOfficeDashboardCard(
      title: '고객 문의 요약',
      value: '미응답 6건',
      summary: '앱·스마트스토어·자동화 견적 문의가 집중되어 AI홍보.마케팅부가 우선 응대·정리 중입니다.',
      status: AiSystemStatus.warning,
      department: 'AI홍보.마케팅부',
    ),
    AiOfficeDashboardCard(
      title: '개발 진행 상황',
      value: '68%',
      summary: '소통AI여행 일본 여행 기능 설계와 다운로드센터 개선안이 병행 검토 중입니다.',
      status: AiSystemStatus.monitoring,
      department: 'AI지시진행부',
    ),
    AiOfficeDashboardCard(
      title: '홍보·고객대응 진행',
      value: '캠페인 4개 · 문의 6건',
      summary: '앱 홍보 영상, 전자책 티저, FAQ 정리, 고객 피드백 전달이 병행 진행 중입니다.',
      status: AiSystemStatus.automaticReportPending,
      department: 'AI홍보.마케팅부',
    ),
    AiOfficeDashboardCard(
      title: '세무회계 체크사항',
      value: '2건',
      summary: '이번 달 비용 분류와 부가세 일정 샘플 알림을 확인해야 합니다.',
      status: AiSystemStatus.approvalRequired,
      department: 'AI세무회계부',
    ),
    AiOfficeDashboardCard(
      title: '투자/재테크 제안',
      value: '보수적 운용',
      summary: '단기 운영자금은 유지하고 홍보비 증액은 성과 조건부 승인으로 제안합니다.',
      status: AiSystemStatus.monitoring,
      department: 'AI세무회계부',
    ),
    AiOfficeDashboardCard(
      title: 'AI전략회의 결과 요약',
      value: '조건부 추진',
      summary: '소통AI여행 일본 여행 기능은 MVP 범위를 축소해 우선 개발하는 안이 우세합니다.',
      status: AiSystemStatus.approvalRequired,
      department: 'AI전략부',
    ),
    AiOfficeDashboardCard(
      title: 'AI아이디어회의 신규 제안',
      value: '6건',
      summary: '소통AI여행, AI전자책 제작도우미, AI산업자동화 견적도우미가 상위 후보로 평가되었습니다.',
      status: AiSystemStatus.notificationPending,
      department: 'AI기획.아이디어부',
    ),
  ];

  static const approvalTasks = <AiApprovalTask>[
    AiApprovalTask(
      title: '소통AI여행 일본 여행 기능 우선 개발',
      department: 'AI지시진행부',
      requestedBy: 'AI전략부',
      reason: '다운로드 증가와 문의 전환이 동시에 감지되어 MVP 개발 승인 필요',
      dueLabel: '오늘 오전',
      status: AiSystemStatus.approvalRequired,
    ),
    AiApprovalTask(
      title: '전자책 신규 등록 및 티저 페이지 공개',
      department: 'AI홍보.마케팅부',
      requestedBy: 'AI기획.아이디어부',
      reason: '앱 홍보와 교차 판매가 가능한 신규 전자책 후보 등록 요청',
      dueLabel: '오늘 오후',
      status: AiSystemStatus.approvalRequired,
    ),
    AiApprovalTask(
      title: '다운로드센터 개선안 적용',
      department: 'AI지시진행부',
      requestedBy: 'AI지시진행부',
      reason: '다운로드 이후 문의가 늘어 안내 구조 개선 필요',
      dueLabel: '24시간 내',
      status: AiSystemStatus.approvalRequired,
    ),
  ];

  static const divisionStatuses = <BusinessDivisionStatus>[
    BusinessDivisionStatus(
      name: '소통앱개발사업부',
      healthScore: 82,
      status: '소통AI여행 기능 우선순위 판단 대기',
      revenueSignal: '다운로드 증가와 문의 전환이 발생',
      nextAction: '일본 여행 기능 MVP 승인',
    ),
    BusinessDivisionStatus(
      name: '소통전자책사업부',
      healthScore: 74,
      status: '신규 등록 후보 2건 검토 중',
      revenueSignal: '사전 문의와 묶음 판매 가능성 확인',
      nextAction: '첫 등록 주제와 판매 채널 결정',
    ),
    BusinessDivisionStatus(
      name: '소통자동화사업부',
      healthScore: 69,
      status: '견적도우미 아이디어 평가 중',
      revenueSignal: 'B2B 상담 예약 1건 발생',
      nextAction: '견적 질문 템플릿 정리',
    ),
    BusinessDivisionStatus(
      name: '소통콘텐츠사업부',
      healthScore: 77,
      status: '앱 홍보 영상 제작 승인 대기',
      revenueSignal: '영상 공개 후 다운로드 전환 기대',
      nextAction: '영상 제작 범위와 광고비 결정',
    ),
  ];

  static const departments = <AiDepartment>[
    AiDepartment(
      id: 'ceo',
      name: 'AI대표',
      leaderRole: 'AI 대표 · 최종 판단',
      summary:
          '전체 사업을 총괄 판단합니다. 각 사업부와 AI부서 보고를 종합해 '
          '수익성·진행·문제·다음 행동을 판단하고 대표에게 최종 보고합니다.',
      status: AiSystemStatus.monitoring,
      progressPercent: 85,
      monitoredWorks: [
        '사업부·AI부서 종합 브리핑',
        '승인 대기 5건 검토',
        '수익·지연·리스크 판단',
        '대표 확인 필요 항목 정리',
      ],
      nextAction: '오늘의 최종 보고서 작성',
    ),
    AiDepartment(
      id: 'productdev',
      name: 'AI상품개발부',
      leaderRole: 'AI 상품·기술 구성',
      summary:
          '각 소통사업부가 진행 중인 상품을 더 발전적으로 만들 수 있도록 '
          '활용 가능한 AI와 기술 기능, 활용도를 사업부별로 정리하고 '
          '추가 상품 구성을 지원합니다. 개발 완료 상품의 등록·카탈로그화와 '
          '버전·유지보수·이슈 관리까지 담당하여 소통총관제에서 상품 전 주기를 '
          '효율적으로 운영할 수 있도록 합니다.',
      status: AiSystemStatus.notificationPending,
      progressPercent: 76,
      monitoredWorks: [
        '등록 대기: AI전자책 제작도우미',
        '유지보수: 소통AI여행 v0.3',
        '검수: AI산업자동화 견적도우미',
        '등록 완료: 소통총관제 v1',
        '사업부별 AI·기술 구성안 갱신',
      ],
      nextAction: '견적도우미 검수 완료 → 상품 등록 · 소통AI여행 패치 계획',
    ),
    AiDepartment(
      id: 'workorder',
      name: 'AI지시진행부',
      leaderRole: 'AI 실행·진행 관리',
      summary:
          '오늘 해야 할 일, 진행 중·지연 작업, Cursor/GitHub/Flutter/홍보/앱개발 '
          '실행 지시와 완료·보류·재검토 상태를 관리합니다.',
      status: AiSystemStatus.automaticReportPending,
      progressPercent: 74,
      monitoredWorks: [
        '오늘: PUBLIC Pages 404 점검',
        '진행: 소통여행 APK·프로모 연결',
        '지연: 소통사매앱 데이터 구조',
        'Cursor/GitHub 배포 파이프라인',
        'Flutter 앱 빌드·테스트',
      ],
      nextAction: '지연 작업 2건 우선순위 재배치',
    ),
    AiDepartment(
      id: 'strategy',
      name: 'AI전략부',
      leaderRole: 'AI 전략·성장 로드맵',
      summary:
          '장기 성장 전략, 월 수익 목표, 사업 확장 로드맵, 소통웨어 전체 방향, '
          '1인 기업에서 AI 기반 기업 시스템으로 성장하는 구조를 설계합니다.',
      status: AiSystemStatus.monitoring,
      progressPercent: 68,
      monitoredWorks: [
        '2026 분기 성장 로드맵',
        '월 수익 목표 ₩500만 샘플',
        '앱·자동화·콘텐츠·전자책 확장',
        'AI 기업 시스템 전환 구조',
      ],
      nextAction: '일본 여행 MVP 전략안 대표 보고',
    ),
    AiDepartment(
      id: 'idea',
      name: 'AI기획.아이디어부',
      leaderRole: 'AI 기획·아이디어',
      summary:
          '신규 앱·농촌·자동화·AI·건강·콘텐츠·전자책 아이디어의 우선순위, '
          '개발 가능성, 수익화 가능성을 평가합니다.',
      status: AiSystemStatus.notificationPending,
      progressPercent: 71,
      monitoredWorks: [
        '소통AI여행 — 지금 실행',
        'AI전자책 제작도우미 — 지금 실행',
        'AI귀농도우미 — 3개월 후 검토',
        '소통건강 — 보류·법적 검토',
      ],
      nextAction: '아이디어 TOP 3 우선순위 확정',
    ),
    AiDepartment(
      id: 'marketing',
      name: 'AI홍보.마케팅부',
      leaderRole: '홍보·마케팅·온라인 고객대응',
      summary:
          '각 앱·사업부별 홍보 전략, 프로모 사이트, 유튜브·블로그·카카오·검색 노출, '
          '배포 링크 관리와 함께 온라인 고객 문의·상담·피드백을 통합 대응합니다.',
      status: AiSystemStatus.automaticReportPending,
      progressPercent: 72,
      monitoredWorks: [
        '앱 홍보 영상 30초 시나리오',
        'GitHub Pages 4개 총괄 점검',
        '미응답 고객 문의 6건 우선 대응',
        '스마트스토어·앱·전자책 구매자 문의 분류',
        '반복 문의 FAQ 초안 정리',
        '고객 피드백 → AI전략부·AI기획.아이디어부 전달',
      ],
      nextAction: '긴급 문의 2건 응대 · 프로모 404 점검',
    ),
    AiDepartment(
      id: 'tax',
      name: 'AI세무회계부',
      leaderRole: 'AI 세무·회계',
      summary:
          '개인사업자·스마트스토어·앱·전자책·광고 수익 분류, 부가세·종합소득세, '
          '비용·예산·투자·세금 체크, 홈택스 신고 준비를 돕습니다.',
      status: AiSystemStatus.approvalRequired,
      progressPercent: 64,
      monitoredWorks: [
        '오늘 매출 ₩428,000 샘플',
        '앱·전자책·광고 수익 분류',
        '부가세 일정 알림',
        '비용·예산·투자 체크',
      ],
      nextAction: '비용 분류 기준 승인',
    ),
  ];

  static const strategyMeeting = AiStrategyMeeting(
    weekLabel: '이번 주 핵심 안건',
    coreAgenda: '소통AI여행 일본 여행 기능 우선 개발 여부',
    agendaExamples: [
      '소통AI여행 일본 여행 기능 우선 개발 여부',
      '전자책 신규 등록 여부',
      '앱 홍보 영상 제작 여부',
      '다운로드센터 개선 여부',
      '광고비 증액 여부',
    ],
    opinions: [
      AiStrategyOpinion(
        department: 'AI대표',
        role: '최종 조정',
        stance: AiOpinionStance.approve,
        opinion: 'MVP 범위를 작게 잡고 일본 여행 기능을 우선 추진하는 안이 타당합니다.',
        reason: '다운로드와 문의가 동시에 증가해 빠른 검증 가치가 있습니다.',
      ),
      AiStrategyOpinion(
        department: 'AI상품개발부',
        role: '개발 범위',
        stance: AiOpinionStance.approve,
        opinion: '숙소·일정·준비물 추천 중 1차는 일정 추천만 구현하면 부담을 낮출 수 있습니다.',
        reason: '핵심 기능을 좁히면 개발 난이도와 테스트 비용이 낮아집니다.',
      ),
      AiStrategyOpinion(
        department: 'AI홍보.마케팅부',
        role: '홍보·고객대응',
        stance: AiOpinionStance.approve,
        opinion: '일본 여행 키워드는 영상과 다운로드센터 개선을 함께 묶어 홍보하기 좋습니다.',
        reason: '명확한 사용 장면이 있어 유입 문구를 만들기 쉽습니다.',
      ),
      AiStrategyOpinion(
        department: 'AI영업부장',
        role: '매출 연결',
        stance: AiOpinionStance.caution,
        opinion: '무료 다운로드 증가만으로는 매출이 약하므로 전자책·상담 상품 연결이 필요합니다.',
        reason: '전환 구조 없이 개발하면 운영 부담만 늘어날 수 있습니다.',
      ),
      AiStrategyOpinion(
        department: 'AI홍보.마케팅부',
        role: '온라인 고객대응',
        stance: AiOpinionStance.caution,
        opinion: '일본 여행 기능 공개 전 FAQ·문의 응대 흐름을 먼저 준비해야 합니다.',
        reason: '문의 폭증 시 응대 지연과 피드백 누락이 발생할 수 있습니다.',
      ),
      AiStrategyOpinion(
        department: 'AI세무회계부장',
        role: '비용 점검',
        stance: AiOpinionStance.caution,
        opinion: '홍보비 증액은 다운로드 전환 목표를 정한 뒤 조건부로 집행해야 합니다.',
        reason: '광고비 지출 기준이 없으면 수익 추적이 어려워집니다.',
      ),
      AiStrategyOpinion(
        department: 'AI투자관리부장',
        role: '자금 운용',
        stance: AiOpinionStance.oppose,
        opinion: '광고비를 즉시 크게 늘리는 안은 보류하고 소액 테스트부터 진행해야 합니다.',
        reason: '운영자금 안정성이 더 중요합니다.',
      ),
      AiStrategyOpinion(
        department: 'AI운영관리부장',
        role: '운영 안정성',
        stance: AiOpinionStance.approve,
        opinion: '자동 점검 항목에 다운로드 실패, 문의 증가, 배포 상태를 추가하면 운영 가능합니다.',
        reason: '24시간 관제 화면에서 실패/주의 상태를 빠르게 확인할 수 있습니다.',
      ),
    ],
    expectedEffect: '일본 여행 관심 고객 유입 증가, 앱 다운로드 상승, 전자책·상담 상품 연결 가능성 확대',
    expectedCost: 'MVP 개발 1차 범위 기준 낮음~중간, 홍보 영상 제작과 소액 광고비는 대표 승인 필요',
    risk: '기능 범위가 커지면 개발 지연 가능. 광고비 증액은 전환 목표 없이 집행하면 손실 위험이 있습니다.',
    finalProposal:
        '일본 여행 기능은 일정 추천 MVP로 우선 개발하고, 광고비는 다운로드 전환 기준을 정한 뒤 소액 테스트로 승인하는 것을 제안합니다.',
  );

  static const ideaProposals = <AiIdeaProposal>[
    AiIdeaProposal(
      title: '소통AI여행',
      marketScore: 86,
      developmentDifficulty: '중간',
      estimatedDevelopmentPeriod: 'MVP 2~4주 범위',
      expectedProfitability: '앱 유입 + 전자책/상담 연결 가능',
      competitionIntensity: '높음',
      sotongwareFit: '매우 높음',
      departmentOpinions: [
        '상품개발: 일정 추천 MVP 우선',
        '마케팅: 홍보 영상과 궁합 좋음',
        '영업: 전환 상품 필요',
      ],
      finalJudgement: '지금 실행',
    ),
    AiIdeaProposal(
      title: '소통건강',
      marketScore: 74,
      developmentDifficulty: '높음',
      estimatedDevelopmentPeriod: '검토 3개월 이상',
      expectedProfitability: '구독형 가능성 있으나 신뢰성 검증 필요',
      competitionIntensity: '매우 높음',
      sotongwareFit: '중간',
      departmentOpinions: [
        '상품개발: 의료성 표현 주의',
        '고객지원: 민감 문의 대응 필요',
        '리스크: 법적 검토 필요',
      ],
      finalJudgement: '3개월 후 검토',
    ),
    AiIdeaProposal(
      title: 'AI차량관리',
      marketScore: 71,
      developmentDifficulty: '중간',
      estimatedDevelopmentPeriod: 'MVP 1~2개월',
      expectedProfitability: '정비 알림·지역 업체 제휴 가능',
      competitionIntensity: '중간',
      sotongwareFit: '중간',
      departmentOpinions: ['마케팅: 지역형 콘텐츠 가능', '영업: 제휴 구조 필요', '투자: 초기 비용 보수적'],
      finalJudgement: '3개월 후 검토',
    ),
    AiIdeaProposal(
      title: 'AI귀농도우미',
      marketScore: 79,
      developmentDifficulty: '중간',
      estimatedDevelopmentPeriod: '콘텐츠 MVP 1개월',
      expectedProfitability: '전자책·상담·콘텐츠 연계 가능',
      competitionIntensity: '중간',
      sotongwareFit: '높음',
      departmentOpinions: [
        '아이디어: 대표 경험과 잘 맞음',
        '마케팅: 콘텐츠화 쉬움',
        '상품개발: 데이터 확보 필요',
      ],
      finalJudgement: '3개월 후 검토',
    ),
    AiIdeaProposal(
      title: 'AI전자책 제작도우미',
      marketScore: 83,
      developmentDifficulty: '낮음~중간',
      estimatedDevelopmentPeriod: 'MVP 2주 범위',
      expectedProfitability: '전자책 제작·판매 자동화로 직접 연결',
      competitionIntensity: '중간',
      sotongwareFit: '매우 높음',
      departmentOpinions: [
        '상품개발: 빠른 프로토타입 가능',
        '마케팅: 제작 사례 홍보 가능',
        '세무회계: 판매 정산 흐름 필요',
      ],
      finalJudgement: '지금 실행',
    ),
    AiIdeaProposal(
      title: 'AI산업자동화 견적도우미',
      marketScore: 81,
      developmentDifficulty: '중간',
      estimatedDevelopmentPeriod: '질문 템플릿 MVP 2~3주',
      expectedProfitability: 'B2B 상담 전환과 견적 품질 향상',
      competitionIntensity: '낮음~중간',
      sotongwareFit: '매우 높음',
      departmentOpinions: [
        '영업: 상담 품질 상승',
        '상품개발: 질문 흐름 설계 필요',
        '투자: 수익성 대비 비용 양호',
      ],
      finalJudgement: '지금 실행',
    ),
  ];

  static const notifications = <AiNotification>[
    AiNotification(
      title: '소통앱개발 상품 구성안 갱신',
      department: 'AI상품개발부',
      type: AiNotificationType.developmentDone,
      importance: '보통',
      occurredAt: '오늘 05:48',
      status: AiSystemStatus.notificationPending,
      detail: '소통AI여행 일본 여행 MVP에 Gemini 일정 추천·지도 API·오프라인 캐시 구성안이 정리되었습니다.',
    ),
    AiNotification(
      title: '다운로드센터 경로 점검 필요',
      department: 'AI지시진행부',
      type: AiNotificationType.urgent,
      importance: '긴급',
      occurredAt: '오늘 06:04',
      status: AiSystemStatus.warning,
      detail: '일부 다운로드 안내 링크에서 문의가 증가했습니다. 실제 서버 연동 전 더미 상태로 표시합니다.',
    ),
    AiNotification(
      title: '일본 여행 기능 개발 승인 요청',
      department: 'AI지시진행부',
      type: AiNotificationType.approvalRequired,
      importance: '높음',
      occurredAt: '오늘 05:52',
      status: AiSystemStatus.approvalRequired,
      detail: '전략회의 결과 MVP 우선 개발 승인이 필요합니다.',
    ),
    AiNotification(
      title: '다운로드센터 개선안 1차 완료',
      department: 'AI지시진행부',
      type: AiNotificationType.developmentDone,
      importance: '보통',
      occurredAt: '오늘 05:40',
      status: AiSystemStatus.completed,
      detail: '안내 문구와 카테고리 개선안이 준비되었습니다.',
    ),
    AiNotification(
      title: '고객 문의 6건 미응답',
      department: 'AI홍보.마케팅부',
      type: AiNotificationType.customerInquiry,
      importance: '높음',
      occurredAt: '오늘 05:35',
      status: AiSystemStatus.warning,
      detail: '앱·스마트스토어·자동화 견적 문의. 긴급 2건 우선 응대 후 AI전략부·기획부에 피드백 전달.',
    ),
    AiNotification(
      title: '오늘 매출 샘플 데이터 갱신',
      department: 'AI세무회계부',
      type: AiNotificationType.revenueGenerated,
      importance: '보통',
      occurredAt: '오늘 05:20',
      status: AiSystemStatus.completed,
      detail: '오늘 매출 더미데이터가 대표실 카드에 반영되었습니다.',
    ),
    AiNotification(
      title: '소통AI여행 자료 다운로드 증가',
      department: 'AI홍보.마케팅부',
      type: AiNotificationType.downloadGenerated,
      importance: '보통',
      occurredAt: '오늘 05:10',
      status: AiSystemStatus.notificationPending,
      detail: '전일 대비 다운로드가 증가했습니다. 홍보 영상 제작과 연결 권장입니다.',
    ),
    AiNotification(
      title: '고객 개선 의견 3건 수집',
      department: 'AI홍보.마케팅부',
      type: AiNotificationType.customerInquiry,
      importance: '보통',
      occurredAt: '오늘 04:55',
      status: AiSystemStatus.notificationPending,
      detail: '앱 기능·전자책 구매 후기·콘텐츠 요청. AI기획.아이디어부 전달 대기.',
    ),
    AiNotification(
      title: '앱 홍보 영상 기획안 완료',
      department: 'AI홍보.마케팅부',
      type: AiNotificationType.marketingDone,
      importance: '보통',
      occurredAt: '오늘 04:48',
      status: AiSystemStatus.completed,
      detail: '30초 홍보 영상 시나리오와 썸네일 문구가 준비되었습니다.',
    ),
    AiNotification(
      title: '부가세 일정 샘플 알림',
      department: 'AI세무회계부',
      type: AiNotificationType.taxSchedule,
      importance: '주의',
      occurredAt: '오늘 04:30',
      status: AiSystemStatus.notificationPending,
      detail: '실제 홈택스 연동 전 더미 세무 일정 알림입니다.',
    ),
    AiNotification(
      title: '광고비 증액 전 투자 점검',
      department: 'AI세무회계부',
      type: AiNotificationType.investmentCheck,
      importance: '높음',
      occurredAt: '오늘 04:15',
      status: AiSystemStatus.approvalRequired,
      detail: '소액 테스트 후 성과 기준을 확인하는 조건부 집행을 제안합니다.',
    ),
    AiNotification(
      title: '자동 점검 시뮬레이션 실패 1건',
      department: 'AI지시진행부',
      type: AiNotificationType.systemError,
      importance: '긴급',
      occurredAt: '오늘 03:58',
      status: AiSystemStatus.failed,
      detail: '실제 백엔드 연동 전 상태값 테스트용 실패 알림입니다.',
    ),
  ];

  static const divisionProductGuides = <DivisionProductDevGuide>[
    DivisionProductDevGuide(
      divisionName: '소통자동화사업부',
      currentProducts: '산업 모니터링 시스템 · AI산업자동화 견적도우미',
      developmentFocus: 'B2B 견적 품질 향상 · 현장 알림 · MES 리포트 자동화',
      recommendations: [
        ProductTechRecommendation(
          aiOrTech: 'GPT-4o',
          category: 'AI',
          feature: '견적 질문·답변 흐름 생성',
          utility: '매우 높음',
          application: '고객 업종별 맞춤 견적 인터뷰 자동 구성',
        ),
        ProductTechRecommendation(
          aiOrTech: 'Claude',
          category: 'AI',
          feature: 'PLC·제어 코드 리뷰 보조',
          utility: '높음',
          application: '현장 제어 로직 검토·문서화 시간 단축',
        ),
        ProductTechRecommendation(
          aiOrTech: 'MQTT / OPC-UA',
          category: '기술',
          feature: '실시간 설비 데이터 수집',
          utility: '매우 높음',
          application: '모니터링 대시보드 핵심 인프라',
        ),
        ProductTechRecommendation(
          aiOrTech: '바코드·QR SDK',
          category: '기술',
          feature: '현장 스캔·추적',
          utility: '높음',
          application: '조립라인·검사라인 추적 상품 패키지',
        ),
      ],
      productEnhancements: [
        'AI 견적도우미 — 업종별 질문 템플릿 자동 생성',
        '현장 이상 알림톡·푸시 연동 패키지',
        'MES 일일 리포트 PDF 자동 생성',
      ],
      nextProductAction: '견적도우미 MVP 질문 흐름 → AI지시진행부 실행 요청',
    ),
    DivisionProductDevGuide(
      divisionName: '소통앱개발사업부',
      currentProducts: '소통AI여행 · 소통사매앱 · 6개 앱 포트폴리오',
      developmentFocus: '일본 여행 MVP · AI 일정 추천 · 지역 생활 정보 고도화',
      recommendations: [
        ProductTechRecommendation(
          aiOrTech: 'Gemini',
          category: 'AI',
          feature: '여행 일정·준비물 추천',
          utility: '매우 높음',
          application: '소통AI여행 일본 여행 MVP 핵심 기능',
        ),
        ProductTechRecommendation(
          aiOrTech: 'OpenAI',
          category: 'AI',
          feature: '앱 내 FAQ·챗봇',
          utility: '높음',
          application: '다운로드 후 문의 전환·온보딩 자동화',
        ),
        ProductTechRecommendation(
          aiOrTech: 'Flutter + Firebase',
          category: '기술',
          feature: '크로스플랫폼·푸시·인증',
          utility: '매우 높음',
          application: '6개 앱 공통 배포·알림 인프라',
        ),
        ProductTechRecommendation(
          aiOrTech: '지도 API',
          category: '기술',
          feature: '위치 기반 일정·관광지',
          utility: '높음',
          application: '여행·지역 생활 앱 상품 차별화',
        ),
      ],
      productEnhancements: [
        '소통AI여행 — 일정 추천 MVP (숙소·준비물은 2차)',
        '소통사매앱 — 지역 카테고리 + AI 생활정보 요약',
        '앱 공통 — 다운로드 후 온보딩 챗봇',
      ],
      nextProductAction: '일본 여행 MVP 범위 확정 → AI지시진행부 개발 지시',
    ),
    DivisionProductDevGuide(
      divisionName: '소통콘텐츠사업부',
      currentProducts: '유튜브·쇼츠 · 앱 홍보 영상 · 지역 생활 콘텐츠',
      developmentFocus: '앱 홍보 영상 자동화 · AI 음악·자막 · 교차 수익',
      recommendations: [
        ProductTechRecommendation(
          aiOrTech: '영상 자막 AI',
          category: 'AI',
          feature: '자동 자막·다국어 번역',
          utility: '높음',
          application: '앱 홍보·쇼츠 제작 시간 단축',
        ),
        ProductTechRecommendation(
          aiOrTech: '이미지·썸네일 AI',
          category: 'AI',
          feature: '썸네일·배너 자동 생성',
          utility: '높음',
          application: '유튜브·프로모 사이트 시각 자료 일괄 제작',
        ),
        ProductTechRecommendation(
          aiOrTech: 'FFmpeg',
          category: '기술',
          feature: '영상 편집·포맷 변환',
          utility: '매우 높음',
          application: '30초 홍보·쇼츠 템플릿 파이프라인',
        ),
        ProductTechRecommendation(
          aiOrTech: 'YouTube API',
          category: '기술',
          feature: '업로드·통계 연동',
          utility: '중간',
          application: '콘텐츠 성과 → 앱 다운로드 전환 추적',
        ),
      ],
      productEnhancements: [
        '앱 홍보 30초 영상 — AI 시나리오 + 템플릿 자동 편집',
        '지역 생활 시리즈 — 앱·전자책 교차 홍보 번들',
        '쇼츠 → 다운로드센터 랜딩 자동 연결',
      ],
      nextProductAction: '홍보 영상 AI 시나리오 → AI홍보.마케팅부 협업',
    ),
    DivisionProductDevGuide(
      divisionName: '소통전자책사업부',
      currentProducts: '전자책 출간 MVP · AI전자책 제작도우미 후보',
      developmentFocus: '목차·초안 자동화 · 교차 판매 · 제작 사례 홍보',
      recommendations: [
        ProductTechRecommendation(
          aiOrTech: 'Claude',
          category: 'AI',
          feature: '목차·초안·편집 보조',
          utility: '매우 높음',
          application: 'AI전자책 제작도우미 핵심 엔진',
        ),
        ProductTechRecommendation(
          aiOrTech: '이미지 생성 AI',
          category: 'AI',
          feature: '표지·삽화 생성',
          utility: '높음',
          application: '전자책 출간 비주얼 제작 비용 절감',
        ),
        ProductTechRecommendation(
          aiOrTech: 'EPUB / PDF',
          category: '기술',
          feature: '전자책 포맷·배포',
          utility: '매우 높음',
          application: '리디북스·스마트스토어 연동 기반',
        ),
        ProductTechRecommendation(
          aiOrTech: '마크다운 파이프라인',
          category: '기술',
          feature: '원고 → 전자책 변환',
          utility: '높음',
          application: '제작도우미 자동 출판 흐름',
        ),
      ],
      productEnhancements: [
        'AI전자책 제작도우미 — 주제 입력 → 목차·초안 2주 MVP',
        '앱·여행 콘텐츠 → 전자책 번들 상품',
        '제작 사례를 홍보·마케팅부 콘텐츠로 자동 연결',
      ],
      nextProductAction: '첫 출간 주제 선정 → 제작도우미 프로토타입 착수',
    ),
    DivisionProductDevGuide(
      divisionName: '소통온라인판매/확장사업부',
      currentProducts: '스마트스토어 · 확장 판매 채널 검토',
      developmentFocus: 'AI 상품카드 · 구매 후 온보딩 · 교차 판매',
      recommendations: [
        ProductTechRecommendation(
          aiOrTech: 'GPT-4o',
          category: 'AI',
          feature: '상품 설명·키워드 생성',
          utility: '높음',
          application: '스마트스토어 상품 등록 자동화',
        ),
        ProductTechRecommendation(
          aiOrTech: '리뷰 분석 AI',
          category: 'AI',
          feature: '고객 피드백 요약',
          utility: '중간',
          application: '상품 개선·FAQ → AI기획.아이디어부 피드백',
        ),
        ProductTechRecommendation(
          aiOrTech: '스마트스토어 API',
          category: '기술',
          feature: '상품·주문 연동',
          utility: '높음',
          application: '앱·전자책·실물 상품 통합 판매',
        ),
        ProductTechRecommendation(
          aiOrTech: '결제·정산 연동',
          category: '기술',
          feature: '매출 추적',
          utility: '매우 높음',
          application: 'AI세무회계부 수익 분류와 연결',
        ),
      ],
      productEnhancements: [
        '앱·전자책·상담 상품 스마트스토어 번들',
        '구매 후 AI 온보딩 챗봇 (앱 설치·이용 안내)',
        '다운로드센터 → 스마트스토어 전환 랜딩',
      ],
      nextProductAction: '판매 채널 로드맵 → AI전략부와 우선순위 협의',
    ),
  ];

  static const productRegistrationStages = <ProductRegistrationStage>[
    ProductRegistrationStage.planning,
    ProductRegistrationStage.development,
    ProductRegistrationStage.review,
    ProductRegistrationStage.registration,
    ProductRegistrationStage.deployment,
    ProductRegistrationStage.operation,
  ];

  static const productRegistrationPipeline = <ProductRegistrationItem>[
    ProductRegistrationItem(
      productName: '소통AI여행 — 일본 여행 MVP',
      divisionName: '소통앱개발사업부',
      currentStage: ProductRegistrationStage.development,
      summary: 'Gemini 일정 추천·지도 API 연동 개발 중. 완료 후 검수·등록 예정.',
      checklist: [
        'AI·기술 구성안 확정',
        'MVP 기능 개발 (AI지시진행부)',
        '내부 검수·테스트',
        '상품 카탈로그 등록',
        'APK·프로모 배포',
        '운영·유지보수 등록',
      ],
      owner: 'AI상품개발부',
      updatedAt: '오늘 05:30',
    ),
    ProductRegistrationItem(
      productName: 'AI산업자동화 견적도우미',
      divisionName: '소통자동화사업부',
      currentStage: ProductRegistrationStage.review,
      summary: '질문 흐름 MVP 개발 완료. 검수 후 B2B 상품으로 등록 대기.',
      checklist: [
        '견적 질문 템플릿 검수',
        '데모 시나리오 확인',
        '상품 설명·가격 체계 초안',
        'SotongAutomationPromo 연결',
        '고객 문의 흐름 점검',
      ],
      owner: 'AI상품개발부',
      updatedAt: '오늘 04:50',
    ),
    ProductRegistrationItem(
      productName: 'AI전자책 제작도우미',
      divisionName: '소통전자책사업부',
      currentStage: ProductRegistrationStage.planning,
      summary: '목차·초안 자동화 구성안 정리 중. 개발 착수 전 상품 스펙 확정.',
      checklist: [
        '활용 AI·기술 선정 (Claude, EPUB)',
        'MVP 범위·일정 합의',
        '첫 출간 주제 연결',
        '판매 채널 정의',
      ],
      owner: 'AI상품개발부',
      updatedAt: '어제 18:20',
    ),
    ProductRegistrationItem(
      productName: '앱 홍보 30초 영상 패키지',
      divisionName: '소통콘텐츠사업부',
      currentStage: ProductRegistrationStage.registration,
      summary: '시나리오·템플릿 완료. 콘텐츠 상품 카탈로그 등록 진행 중.',
      checklist: [
        '영상 템플릿 확정',
        '썸네일·자막 AI 워크플로우',
        '상품 카탈로그 메타데이터 입력',
        '홍보·마케팅부 연동',
      ],
      owner: 'AI상품개발부',
      updatedAt: '오늘 03:15',
    ),
  ];

  static const registeredProducts = <RegisteredProduct>[
    RegisteredProduct(
      name: '소통총관제',
      divisionName: '소통웨어 통합',
      version: 'v1.0-demo',
      registeredAt: '2026-03-01',
      productType: '웹 관제 · AI 경영 데모',
      channels: ['GitHub Pages', '내부 본사 관제'],
      status: AiSystemStatus.monitoring,
      catalogId: 'PRD-CTL-001',
    ),
    RegisteredProduct(
      name: '소통AI여행',
      divisionName: '소통앱개발사업부',
      version: 'v0.2',
      registeredAt: '2026-02-15',
      productType: '모바일 앱 · 여행 도우미',
      channels: ['APK', 'SotongAppsPromo', '다운로드센터'],
      status: AiSystemStatus.monitoring,
      catalogId: 'PRD-APP-002',
    ),
    RegisteredProduct(
      name: '산업자동화 모니터링 데모',
      divisionName: '소통자동화사업부',
      version: 'v0.1',
      registeredAt: '2026-01-20',
      productType: 'B2B 데모 · 현장 모니터링',
      channels: ['SotongAutomationPromo', 'B2B 제안'],
      status: AiSystemStatus.completed,
      catalogId: 'PRD-AUTO-001',
    ),
    RegisteredProduct(
      name: '소통사매앱',
      divisionName: '소통앱개발사업부',
      version: 'v0.4',
      registeredAt: '2025-12-10',
      productType: '모바일 앱 · 지역 생활',
      channels: ['APK', 'SotongAppsPromo'],
      status: AiSystemStatus.warning,
      catalogId: 'PRD-APP-003',
    ),
    RegisteredProduct(
      name: 'PUBLIC 사업 총괄 프로모 4종',
      divisionName: '소통홍보·연결',
      version: 'v1.0',
      registeredAt: '2026-02-01',
      productType: '웹 프로모 · 사업부 허브',
      channels: [
        'AutomationPromo',
        'AppsPromo',
        'ContentsPromo',
        'EbookPromo',
      ],
      status: AiSystemStatus.monitoring,
      catalogId: 'PRD-PROMO-004',
    ),
  ];

  static const productMaintenanceRegistry = <ProductMaintenanceRecord>[
    ProductMaintenanceRecord(
      productName: '소통AI여행',
      divisionName: '소통앱개발사업부',
      currentVersion: 'v0.2',
      healthScore: 78,
      lastCheckedAt: '오늘 06:00',
      maintenanceTasks: [
        '일본 여행 MVP 개발 연동 준비',
        '다운로드센터 안내 문구 점검',
        'APK·프로모 URL 일치 확인',
      ],
      scheduledUpdates: [
        'v0.3 — 일정 추천 MVP (개발 중)',
        'v0.4 — FAQ 챗봇 온보딩',
      ],
      knownIssues: ['배포 후 홍보 흐름 미완', '일부 다운로드 경로 점검 필요'],
      nextMaintenanceAction: 'MVP 배포 후 v0.3 유지보수 계획 등록',
    ),
    ProductMaintenanceRecord(
      productName: '소통사매앱',
      divisionName: '소통앱개발사업부',
      currentVersion: 'v0.4',
      healthScore: 65,
      lastCheckedAt: '오늘 05:45',
      maintenanceTasks: [
        '지역 데이터 구조 고도화',
        '카테고리·검색 UX 개선',
        '프로모 페이지 정보 동기화',
      ],
      scheduledUpdates: ['v0.5 — AI 생활정보 요약 (기획)'],
      knownIssues: ['데이터 구조 지연', '지역 카테고리 미정리'],
      nextMaintenanceAction: '데이터 구조 설계 → AI지시진행부 실행 요청',
    ),
    ProductMaintenanceRecord(
      productName: '소통총관제',
      divisionName: '소통웨어 통합',
      currentVersion: 'v1.0-demo',
      healthScore: 92,
      lastCheckedAt: '오늘 06:10',
      maintenanceTasks: [
        'AI상품개발부 등록·유지보수 UI 반영',
        'GitHub Pages 배포 확인',
        '사이드바 7개 AI부서 구조 유지',
      ],
      scheduledUpdates: ['v1.1 — 상품 등록 워크플로 확장', 'v1.2 — Firebase 연동 비전'],
      knownIssues: [],
      nextMaintenanceAction: '이번 배포 후 상품 카탈로그 샘플 데이터 갱신',
    ),
    ProductMaintenanceRecord(
      productName: 'PUBLIC 프로모 4종',
      divisionName: '소통홍보·연결',
      currentVersion: 'v1.0',
      healthScore: 71,
      lastCheckedAt: '오늘 05:20',
      maintenanceTasks: [
        'Pages 404 점검 (4개 사이트)',
        '앱·사업부 링크맵 동기화',
        '메타·SEO 문구 점검',
      ],
      scheduledUpdates: ['콘텐츠·전자책 프로모 콘텐츠 보강'],
      knownIssues: ['일부 Pages 경로 404 가능성'],
      nextMaintenanceAction: '404 점검 결과 → AI지시진행부 우선 수정',
    ),
    ProductMaintenanceRecord(
      productName: '산업자동화 모니터링 데모',
      divisionName: '소통자동화사업부',
      currentVersion: 'v0.1',
      healthScore: 80,
      lastCheckedAt: '어제 22:00',
      maintenanceTasks: [
        'B2B 제안서·데모 시나리오 정리',
        'Promo 사이트 최신화',
        '견적도우미 등록 준비 연동',
      ],
      scheduledUpdates: ['견적도우미 v0.1 등록 (검수 중)'],
      knownIssues: ['영업 자료·포트폴리오 보강 필요'],
      nextMaintenanceAction: '견적도우미 등록 완료 시 데모 패키지 번들 업데이트',
    ),
  ];
}
