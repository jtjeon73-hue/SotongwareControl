import '../models/business_division.dart';
import '../models/department.dart';
import '../models/project_item.dart';

class DashboardMetrics {
  const DashboardMetrics({
    required this.activeBusinesses,
    required this.operatingDepartments,
    required this.managedProjects,
    required this.upcomingSites,
    required this.monthlyFocusTasks,
    required this.automatableTasks,
  });

  final int activeBusinesses;
  final int operatingDepartments;
  final int managedProjects;
  final int upcomingSites;
  final int monthlyFocusTasks;
  final int automatableTasks;
}

class SampleBusinessData {
  static const siteTitle = '소통웨어 디지털랩';
  static const siteSubtitle = '사업 운영 관제센터';
  static const siteEnglishName = 'SotongWare Control Center';
  static const siteDescription =
      '전체 사업 현황 파악, 문제 대응, 수익 연결, 영업·홍보, 재무·세무, AI 업무 지시를 한곳에서 관리하는 개인용 운영 대시보드입니다.';

  static const privacyNotice =
      '이 사이트는 개인 사업 관리를 위한 내부용 대시보드입니다. 공개 홍보사이트가 아니며 실제 고객정보, 비밀번호, 세무 상세자료는 저장하지 않습니다.';

  static const metrics = DashboardMetrics(
    activeBusinesses: 4,
    operatingDepartments: 5,
    managedProjects: 13,
    upcomingSites: 9,
    monthlyFocusTasks: 5,
    automatableTasks: 9,
  );

  static const divisions = <BusinessDivision>[
    BusinessDivision(
      id: 'industrial_automation',
      title: '산업자동화 모니터링 시스템',
      description:
          '제조 생산라인의 작업순서, 작업리스트, 바코드, PLC, MES, 작업자 Tool, CSV, 그래프, 데이터 관리, 공정 모니터링을 담당합니다.',
      items: [
        '작업자 작업리스트 관리',
        '작업순서 관리',
        '바코드 연동',
        'PLC 연동',
        'MES 연동',
        '작업자 Tool 연동',
        'CSV 파일 관리',
        '그래프/데이터 관리',
        '생산 공정 조립라인 모니터링',
        '비전 검사 데이터/진행 상황 모니터링',
      ],
      status: '핵심 경험 보유 / 홍보사이트 준비 필요',
      detailDescription:
          '제조 생산라인의 작업 정보와 설비 데이터를 통합 관리하는 PC 기반 모니터링 시스템 사업입니다.',
      detailSections: {
        '주요 경험': [
          '제조 생산라인 PC 기반 모니터링 시스템 구축 경험',
          '작업자 작업리스트 및 작업순서 관리 시스템',
          '바코드·PLC·MES 연동 실무 경험',
          'Torque/Angle 그래프 및 OK/NG 결과 관리',
        ],
        '핵심 기능': [
          '작업자 작업리스트',
          '작업순서 관리',
          '바코드 스캔 연동',
          'PLC 상태 연동',
          'MES 데이터 연동',
          'HANTAS 등 작업자 Tool 연동',
          'CSV 저장/조회',
          'Torque/Angle 그래프',
          'OK/NG 결과 관리',
          '라인별 PC 상태 모니터링',
          '비전 검사 데이터 상황판',
        ],
        '연동 대상': [
          '바코드 스캐너',
          'PLC 설비',
          'MES 시스템',
          '작업자 Tool (HANTAS 등)',
          '비전 검사 장비',
        ],
        '데이터 관리': [
          'CSV 파일 저장/조회',
          '그래프 데이터 시각화',
          'OK/NG 결과 이력 관리',
          '라인별 생산 현황 집계',
        ],
        '홍보사이트 준비 상태': [
          'SotongAutomationPromo 사이트 기획 단계',
          '핵심 기능 소개 페이지 구성 예정',
          '포트폴리오 사례 정리 필요',
        ],
        '다음 작업': [
          '홍보사이트 구조 설계',
          '핵심 기능 데모 화면 캡처',
          '고객 제안서 템플릿 정리',
          '연동 대상 목록 문서화',
        ],
      },
    ),
    BusinessDivision(
      id: 'app_development',
      title: '앱개발 사업부',
      description:
          'Flutter 기반 앱과 AI 서비스 앱을 기획, 개발, APK 테스트, 프로모 사이트, Play Store 등록까지 관리합니다.',
      items: ['소통여행', '소통사주', '팜지기', '소통건강', '소통AI', '소통사매앱'],
      status: '6개 앱 관리 중 (소통사매앱 포함)',
      detailDescription:
          'Flutter, AI API, Firebase, GitHub, Play Store 배포를 기반으로 여러 앱을 기획하고 개발하는 사업부입니다.',
      detailSections: {
        '기술 스택': [
          'Flutter / Dart',
          'AI API 연동',
          'Firebase',
          'GitHub 버전 관리',
          'Play Store 배포',
        ],
        '다음 작업': [
          '소통여행 APK 테스트 진행',
          '소통사매앱 지역 데이터 구조 정리',
          '각 앱 프로모 사이트 기획',
          'Play Store 등록 체크리스트 정리',
        ],
      },
      projects: [
        DivisionProject(
          name: '소통여행',
          englishName: 'SotongTravel',
          purpose: '여행 정보 및 일정 관리 앱',
          currentStage: 'APK 테스트 준비 / 프로모 사이트 준비',
          nextTask: 'APK 테스트 및 프로모 페이지 구성',
          promoRepositoryName: 'SotongTravelPromo',
          promoUrl: 'https://jtjeon73-hue.github.io/SotongTravelPromo/',
          promoStatus: '운영중 / 연결됨',
          isPromoLinked: true,
          promoSiteId: 'travel_promo',
        ),
        DivisionProject(
          name: '소통사주',
          englishName: 'SotongSaju',
          purpose: '사주·운세 기반 콘텐츠 앱',
          currentStage: '기존 개발 경험 보유 / 고도화 예정',
          nextTask: 'UI 개선 및 AI 기능 연동 검토',
          promoRepositoryName: 'SotongSajuPromo',
          promoUrl: 'https://jtjeon73-hue.github.io/SotongSajuPromo/',
          promoStatus: '제작 예정 / 배포 확인 필요',
          isPromoLinked: true,
          promoSiteId: 'saju_promo',
        ),
        DivisionProject(
          name: '팜지기',
          englishName: 'Farmjigi',
          purpose: '농촌 직거래 플랫폼 앱',
          currentStage: '농촌 직거래 앱 구상',
          nextTask: '핵심 기능 정의 및 와이어프레임',
          promoRepositoryName: 'FarmjigiPromo',
          promoUrl: 'https://jtjeon73-hue.github.io/FarmjigiPromo/',
          promoStatus: '제작 예정 / 배포 확인 필요',
          isPromoLinked: true,
          promoSiteId: 'farmjigi_promo',
        ),
        DivisionProject(
          name: '소통건강',
          englishName: 'SotongHealth',
          purpose: 'AI 건강코치 기반 웰니스 앱',
          currentStage: 'AI 건강코치 앱 아이디어',
          nextTask: '건강 데이터 입력 흐름 설계',
          promoRepositoryName: 'SotongHealthPromo',
          promoUrl: 'https://jtjeon73-hue.github.io/SotongHealthPromo/',
          promoStatus: '제작 예정 / 배포 확인 필요',
          isPromoLinked: true,
          promoSiteId: 'health_promo',
        ),
        DivisionProject(
          name: '소통AI',
          englishName: 'SotongAI',
          purpose: 'AI 활용 통합 플랫폼',
          currentStage: 'AI 활용 플랫폼 구상',
          nextTask: '서비스 범위 및 MVP 정의',
          promoRepositoryName: 'SotongAIPromo',
          promoUrl: 'https://jtjeon73-hue.github.io/SotongAIPromo/',
          promoStatus: '제작 예정 / 배포 확인 필요',
          isPromoLinked: true,
          promoSiteId: 'ai_promo',
        ),
        DivisionProject(
          name: '소통사매앱',
          englishName: 'SotongSamae',
          purpose:
              '지역 생활 / 마을 정보 / 지역 홍보 앱. '
              '사매면·지역 생활정보·관광지·마을 소식·생활 편의 정보.',
          currentStage: '프로모 사이트 경험 보유 / 앱 고도화 예정',
          nextTask: '앱 화면 고도화·지역 데이터 구조·프로모 사이트 연결',
          promoRepositoryName: 'SotongSamaePromo',
          promoUrl: 'https://jtjeon73-hue.github.io/SotongSamaePromo/',
          promoStatus: '제작 예정 / 배포 확인 필요',
          isPromoLinked: true,
          promoSiteId: 'samae_promo',
        ),
      ],
    ),
    BusinessDivision(
      id: 'youtube_content',
      title: '유튜브/콘텐츠 사업부',
      description:
          'AI 유튜브 음악, 지역 생활밀착 영상, 시골 생활 콘텐츠, 음악과 영상 결합 콘텐츠를 기획하고 제작합니다.',
      items: [
        'AI 음악 제작',
        '지역 생활 영상',
        '시골 생활 콘텐츠',
        '앱 홍보 영상',
        '짧은 쇼츠 콘텐츠',
        '음악+영상 결합 콘텐츠',
      ],
      status: '콘텐츠 방향 정리 단계',
      detailSections: {
        'AI 음악 제작': ['AI 기반 음악 생성 도구 활용', '가사 및 멜로디 방향 기획', '채널 브랜딩 음악 제작'],
        '지역 생활밀착 영상': ['지역 맛집·명소 소개', '생활 정보 콘텐츠', '지역 커뮤니티 연계 영상'],
        '시골 생활 콘텐츠': ['농촌 일상 브이로그', '계절별 농사·생활 기록', '시골 라이프스타일 공유'],
        '앱 홍보 영상': ['앱 기능 소개 영상', '사용법 튜토리얼', '앱 출시 알림 영상'],
        '쇼츠 콘텐츠': ['짧은 팁·정보 영상', '트렌드 반영 쇼츠', '앱·콘텐츠 홍보 쇼츠'],
        '콘텐츠 캘린더 예정': ['주간 업로드 계획 수립', '시즌별 콘텐츠 테마 정리', '앱 출시 연동 콘텐츠 일정'],
      },
    ),
    BusinessDivision(
      id: 'ebook',
      title: '전자책 개발 사업부',
      description:
          '경험, 기술, 농촌생활, 앱개발, 자동화 시스템, AI 활용 노하우를 전자책으로 기획하고 판매하는 사업부입니다.',
      items: [
        '전자책 주제 기획',
        '원고 작성',
        '표지/목차 구성',
        'PDF/ePub 제작',
        '판매 페이지 연결',
        '스마트스토어/크몽/탈잉 등 확장 가능성',
      ],
      status: '초기 기획 단계',
      detailSections: {
        '전자책 주제 후보': [
          'Flutter 앱개발 입문서',
          '농촌생활 실전 가이드',
          'AI 활용 업무 자동화 노하우',
          '산업자동화 시스템 구축 경험서',
        ],
        '기술 경험 정리': ['Flutter/Dart 개발 경험', 'Firebase 연동 노하우', 'AI API 활용 사례'],
        '농촌생활 경험 정리': ['시골 이주·적응 경험', '농사·직거래 경험', '지역 생활 콘텐츠 소재'],
        'AI 활용 노하우': ['Cursor AI 개발 활용', '콘텐츠 제작 AI 도구', '업무 자동화 프롬프트'],
        '앱개발 입문서': ['Flutter 시작 가이드', '앱 기획부터 배포까지', 'Play Store 등록 절차'],
        '산업자동화 경험서': ['PLC/MES 연동 실무', '모니터링 시스템 구축', '제조 현장 데이터 관리'],
        '판매 채널 후보': ['자체 판매 페이지', '스마트스토어', '크몽 / 탈잉', '전자책 플랫폼'],
      },
    ),
  ];

  static const departments = <Department>[
    Department(
      id: 'tax_accounting',
      title: '세무·회계·예산·재테크',
      role: '매출, 비용, 부가세, 세금계산서, 예산, 연금, ETF, 재테크, 사업자 관리',
      taskCards: [
        DepartmentTaskCard(
          title: '매출 관리',
          description: '사업부별 매출 현황 추적 및 월별 집계',
        ),
        DepartmentTaskCard(
          title: '비용 관리',
          description: '운영비, 개발비, 마케팅비 분류 및 기록',
        ),
        DepartmentTaskCard(
          title: '부가세/세금계산서',
          description: '부가세 신고 준비 및 세금계산서 발행 관리',
        ),
        DepartmentTaskCard(title: '사업자 관리', description: '사업자 등록 정보 및 업종 관리'),
        DepartmentTaskCard(
          title: '연금/ETF/재테크',
          description: '개인 재테크 포트폴리오 및 연금 계획',
        ),
        DepartmentTaskCard(
          title: '월별 예산표 예정',
          description: '사업부별 월간 예산 계획 및 실적 비교',
        ),
      ],
    ),
    Department(
      id: 'planning',
      title: '기획·아이디어',
      role: '앱 아이디어, 콘텐츠 아이디어, 전자책 주제, 자동화 시스템 기획, 사업 우선순위 정리',
      taskCards: [
        DepartmentTaskCard(
          title: '앱 아이디어',
          description: '신규 앱 컨셉 및 기능 아이디어 수집',
        ),
        DepartmentTaskCard(
          title: '자동화 시스템 아이디어',
          description: '산업자동화 확장 및 신규 시스템 기획',
        ),
        DepartmentTaskCard(
          title: '유튜브 콘텐츠 아이디어',
          description: '채널 콘텐츠 주제 및 시리즈 기획',
        ),
        DepartmentTaskCard(
          title: '전자책 주제',
          description: '전자책 출판 주제 선정 및 목차 구상',
        ),
        DepartmentTaskCard(
          title: '수익자동화 아이디어',
          description: '패시브 인컴 및 자동화 수익 모델 검토',
        ),
        DepartmentTaskCard(
          title: '우선순위 결정',
          description: '사업부·프로젝트 우선순위 매트릭스 관리',
        ),
      ],
    ),
    Department(
      id: 'online_sales',
      title: '온라인영업·고객대응',
      role: '홈페이지, 제안서, 고객 문의, 계약 전 상담, 온라인 홍보, B2B 영업 관리',
      taskCards: [
        DepartmentTaskCard(title: '제안서', description: 'B2B 고객 대상 제안서 작성 및 관리'),
        DepartmentTaskCard(title: '상담 기록', description: '고객 상담 이력 및 후속 조치 관리'),
        DepartmentTaskCard(title: '고객 문의', description: '온라인 문의 접수 및 응대 현황'),
        DepartmentTaskCard(
          title: '홈페이지/홍보사이트',
          description: '공개 홍보사이트 기획 및 운영 관리',
        ),
        DepartmentTaskCard(title: 'B2B 영업', description: '기업 고객 영업 파이프라인 관리'),
        DepartmentTaskCard(title: '견적 관리', description: '프로젝트 견적 산출 및 이력 관리'),
      ],
    ),
    Department(
      id: 'sales',
      title: '판매·고객대응',
      role: '소통창고, 스마트스토어, 상품 등록, 주문 관리, 배송/고객 응대, 리뷰 관리',
      taskCards: [
        DepartmentTaskCard(title: '소통창고', description: '자체 쇼핑몰 운영 및 상품 관리'),
        DepartmentTaskCard(
          title: '스마트스토어 연결',
          description: '네이버 스마트스토어 연동 및 운영',
        ),
        DepartmentTaskCard(title: '상품 등록', description: '신규 상품 등록 및 정보 관리'),
        DepartmentTaskCard(title: '주문 관리', description: '주문 접수·처리·배송 현황 추적'),
        DepartmentTaskCard(title: '배송 관리', description: '배송 업체 연동 및 배송 상태 관리'),
        DepartmentTaskCard(
          title: '리뷰/고객 응대',
          description: '고객 리뷰 모니터링 및 응대 기록',
        ),
      ],
    ),
    Department(
      id: 'ai_agent_room',
      title: 'AI 직원실',
      role: '각 부서별 AI 역할을 정의하고, AI가 업무를 어떻게 도와줄지 관리',
      taskCards: [],
    ),
  ];

  static const projectLinks = <ProjectLinkItem>[
    ProjectLinkItem(
      id: 'control_center',
      name: 'SotongWare Control Center',
      description: 'private 내부 총괄 관제센터 (현재 사이트)',
      type: ProjectLinkType.internal,
    ),
    ProjectLinkItem(
      id: 'automation_promo',
      name: 'SotongAutomationPromo',
      description: '산업자동화 공개 홍보사이트 예정',
      type: ProjectLinkType.publicPromo,
    ),
    ProjectLinkItem(
      id: 'apps_promo',
      name: 'SotongAppsPromo',
      description: '앱개발 총괄 공개 홍보사이트 예정',
      type: ProjectLinkType.publicPromo,
    ),
    ProjectLinkItem(
      id: 'travel_promo',
      name: 'SotongTravelPromo',
      description: '소통여행 개별 프로모 사이트',
      type: ProjectLinkType.publicPromo,
    ),
    ProjectLinkItem(
      id: 'saju_promo',
      name: 'SotongSajuPromo',
      description: '소통사주 개별 프로모 사이트',
      type: ProjectLinkType.publicPromo,
    ),
    ProjectLinkItem(
      id: 'farmjigi_promo',
      name: 'FarmjigiPromo',
      description: '팜지기 개별 프로모 사이트',
      type: ProjectLinkType.publicPromo,
    ),
    ProjectLinkItem(
      id: 'samae_promo',
      name: 'SotongSamaePromo',
      description: '소통사매앱 개별 프로모 사이트',
      type: ProjectLinkType.publicPromo,
    ),
    ProjectLinkItem(
      id: 'youtube_promo',
      name: 'SotongYouTubePromo',
      description: '유튜브/콘텐츠 공개 홍보사이트 예정',
      type: ProjectLinkType.publicPromo,
    ),
    ProjectLinkItem(
      id: 'ebook_promo',
      name: 'SotongEbookPromo',
      description: '전자책 공개 홍보사이트 예정',
      type: ProjectLinkType.publicPromo,
    ),
    ProjectLinkItem(
      id: 'warehouse',
      name: 'SotongWarehouse',
      description: '소통창고/스마트스토어 연결 예정',
      type: ProjectLinkType.commerce,
    ),
  ];

  static BusinessDivision? divisionById(String id) {
    try {
      return divisions.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  static Department? departmentById(String id) {
    try {
      return departments.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}
