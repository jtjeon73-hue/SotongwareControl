import 'package:flutter/material.dart';

import '../widgets/sidebar_navigation.dart';

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

class AiDepartmentRoleSummary {
  const AiDepartmentRoleSummary({
    required this.name,
    required this.summary,
    required this.destination,
    required this.icon,
  });

  final String name;
  final String summary;
  final ControlDestination destination;
  final IconData icon;
}

class ManagementHubData {
  static const visionNote =
      'AI대표가 사업부·AI부서 보고를 종합해 수익성·진행·문제·다음 행동을 판단하고 '
      '대표에게 최종 보고합니다. 현재는 데모 데이터입니다.';

  static const divisionStatuses = <HubStatusItem>[
    HubStatusItem(
      name: '소통자동화사업부',
      progress: 72,
      status: 'B2B 제안·데모 자료 정리 중',
      priority: '높음',
      nextAction: 'SotongAutomationPromo 배포 확인',
      tag: '수익 연결',
    ),
    HubStatusItem(
      name: '소통앱개발사업부',
      progress: 58,
      status: '6개 앱·프로모 URL 연결 완료',
      priority: '높음',
      nextAction: '소통여행 배포·소통사매앱 고도화',
      tag: '우선 처리',
    ),
    HubStatusItem(
      name: '소통콘텐츠사업부',
      progress: 35,
      status: '콘텐츠 방향 정리·업로드 일정 필요',
      priority: '중간',
      nextAction: '주간 콘텐츠 캘린더 확정',
      tag: '발전 가능',
    ),
    HubStatusItem(
      name: '소통전자책사업부',
      progress: 28,
      status: '출간 주제·목차 후보 정리',
      priority: '중간',
      nextAction: '첫 전자책 MVP 주제 선정',
      tag: '발전 가능',
    ),
    HubStatusItem(
      name: '소통온라인판매/확장사업부',
      progress: 22,
      status: '스마트스토어·확장 채널 검토',
      priority: '중간',
      nextAction: '판매 채널·확장 로드맵 초안',
      tag: '향후 확장',
    ),
  ];

  static const aiDepartmentRoles = <AiDepartmentRoleSummary>[
    AiDepartmentRoleSummary(
      name: 'AI대표',
      summary: '전체 판단·최종 의사결정 보조·대표 보고',
      destination: ControlDestination.aiRepresentative,
      icon: Icons.psychology_outlined,
    ),
    AiDepartmentRoleSummary(
      name: 'AI상품개발부',
      summary: '사업부별 AI·기술 활용 · 추가 상품 구성 · 등록 · 유지보수',
      destination: ControlDestination.aiProductDevDept,
      icon: Icons.inventory_2_outlined,
    ),
    AiDepartmentRoleSummary(
      name: 'AI지시진행부',
      summary: '해야 할 일·진행 체크·실행 명령·작업 흐름',
      destination: ControlDestination.aiWorkOrderDept,
      icon: Icons.assignment_outlined,
    ),
    AiDepartmentRoleSummary(
      name: 'AI전략부',
      summary: '장기 성장·월 수익 목표·사업 확장 로드맵',
      destination: ControlDestination.aiStrategyDept,
      icon: Icons.auto_graph_outlined,
    ),
    AiDepartmentRoleSummary(
      name: 'AI기획.아이디어부',
      summary: '신규 앱·아이디어 우선순위·수익화 가능성',
      destination: ControlDestination.aiIdeaPlanningDept,
      icon: Icons.tips_and_updates_outlined,
    ),
    AiDepartmentRoleSummary(
      name: 'AI홍보.마케팅부',
      summary: '홍보 · 마케팅 · 온라인 고객대응 관리',
      destination: ControlDestination.aiMarketingDept,
      icon: Icons.campaign_outlined,
    ),
    AiDepartmentRoleSummary(
      name: 'AI세무회계부',
      summary: '수익 분류·세금·비용·예산·홈택스 준비',
      destination: ControlDestination.aiTaxAccountingDept,
      icon: Icons.receipt_long_outlined,
    ),
  ];

  static const revenueStageItems = <String>[
    '산업자동화 B2B — 상담·제안 단계',
    '앱 — APK·프로모·Play Store 준비',
    '전자책·스마트스토어 — 출간 MVP 선정',
    '콘텐츠·광고 — 유입·전환 구조 설계',
    '온라인판매 — 확장 채널 검토',
  ];

  static const topTasks = <String>[
    '소통여행 배포·프로모 완성',
    'PUBLIC Pages 404 점검',
    '소통사매앱 지역 데이터 고도화',
    '재무·세금 월간 루틴 확립',
    'AI대표 승인 대기 5건 처리',
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
      area: '세무',
      title: '월간 매출·비용 입력 루틴',
      detail: 'AI세무회계부에서 샘플 데이터 정기 점검',
    ),
    HubCheckPoint(
      area: '산업자동화',
      title: 'B2B 제안서·포트폴리오',
      detail: '제조 고객 대상 핵심 경험 중심 자료 정리',
    ),
  ];

  static const priorityItems = <String>[
    '소통여행 배포·프로모 완성',
    'AI세무회계부 홈택스 연동 로드맵',
    'PUBLIC 홍보사이트 Pages 배포 확인',
    '소통사매앱 지역 데이터 구조 고도화',
    '다운로드센터 경로 점검',
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
    '이번 달: AI세무회계부 점검 루틴 확립',
    '다음 분기: 1인 기업 → AI 기업 시스템 성장',
  ];

  static const ceoReviewItems = <String>[
    '소통AI여행 일본 여행 기능 MVP 승인',
    '전자책 신규 등록·티저 공개 여부',
    '광고비 증액 조건부 승인',
    '다운로드센터 개선안 적용',
    '비용 분류 기준 승인',
  ];

  static const aiTodayBriefing = '''
소통웨어 전체 사업은 「앱 배포·홍보 연결·재무 기반」 3축에서 동시에 움직여야 합니다.
단기 수익은 산업자동화 B2B와 소통여행 배포, 중기 성장은 6개 앱 포트폴리오와 콘텐츠,
장기 경쟁력은 AI세무회계부의 홈택스 연동과 AI대표 의사결정 체계입니다.''';

  static const divisionBriefs = <AiDivisionBrief>[
    AiDivisionBrief(
      divisionName: '소통자동화',
      currentStatus: '핵심 경험 보유, B2B 홍보 강화 단계',
      progressSummary: '제안서·데모·Promo 연결 진행',
      revenueDirection: '제조 현장 모니터링 구축·유지보수',
      growthDirection: '바코드·PLC·MES 통합 패키지화',
      recommendedActions: ['제안서 목차 확정', 'Promo 404 확인', '데모 시나리오 1건'],
    ),
    AiDivisionBrief(
      divisionName: '소통앱개발',
      currentStatus: '6개 앱·6개 프로모 URL 연결',
      progressSummary: '소통여행 배포·소통사매 고도화가 핵심',
      revenueDirection: 'Play Store·프로모 유입·APK 배포',
      growthDirection: '앱 포트폴리오 + AI 기능 확장',
      recommendedActions: ['소통여행 배포', '사매앱 카테고리 정리', 'Pages 점검'],
    ),
  ];

  static const aiDepartmentBriefs = <AiDepartmentBrief>[
    AiDepartmentBrief(
      departmentName: 'AI상품개발부',
      currentStatus: '5개 사업부 구성안 · 등록 파이프라인 · 유지보수 관리',
      keyProposal: '상품 기획→등록→운영 전 주기와 사업부별 AI·기술 카탈로그',
      riskOrGap: '등록·유지보수 체계 없이 개발만 하면 상품 자산 관리 불가',
      recommendedActions: [
        '견적도우미 검수 완료 → 상품 등록',
        '등록 상품 버전·이슈 주간 점검',
        '유지보수 계획 → AI지시진행부 실행 연결',
      ],
    ),
    AiDepartmentBrief(
      departmentName: 'AI기획.아이디어부',
      currentStatus: '신규 아이디어·우선순위 정리',
      keyProposal: '분기 로드맵·신규 아이디어·성장 전략 통합',
      riskOrGap: '우선순위 미확정 시 리소스 분산',
      recommendedActions: ['로드맵 확정', '신규 아이디어 3건', '성장 시나리오'],
    ),
    AiDepartmentBrief(
      departmentName: 'AI홍보.마케팅부',
      currentStatus: '홍보·프로모 연결 + 온라인 고객 문의 응대',
      keyProposal: '홍보·마케팅·온라인 고객대응 통합 관리',
      riskOrGap: '문의 지연 시 신뢰도·유입 전환 동시 하락',
      recommendedActions: ['미응답 문의 우선 응대', 'FAQ 정리', '피드백 → AI전략부·기획부 전달'],
    ),
    AiDepartmentBrief(
      departmentName: 'AI세무회계부',
      currentStatus: '재무 입력·세무 점검 체계 구축 중',
      keyProposal: '홈택스 연동·자금 흐름·절세·재테크 AI 보조',
      riskOrGap: '세무·비용 누락 시 성장 리스크',
      recommendedActions: ['월간 재무 루틴', '홈택스 로드맵', '투자·재테크 점검'],
    ),
  ];

  static const departmentBriefs = aiDepartmentBriefs;

  static const executionProposals = <AiExecutionProposal>[
    AiExecutionProposal(
      title: '소통여행 배포 우선 실행',
      description: 'APK·프로모·설치 안내를 한 흐름으로 연결',
      impact: '단기 수익·실적 가시화',
      suggestedDecision: '진행 권장',
    ),
    AiExecutionProposal(
      title: 'AI세무회계부 홈택스 로드맵 착수',
      description: '세무 점검·재무 리포트 자동화 방향 문서화',
      impact: '장기 기업 성장 기반',
      suggestedDecision: '우선 검토',
    ),
  ];
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
