import 'package:flutter/material.dart';

import '../data/ai_control_center_data.dart';
import '../models/ai_control_center.dart';
import '../theme/control_theme.dart';
import '../widgets/control_section_title.dart';
import '../widgets/page_hero.dart';

class AiCeoOfficeScreen extends StatelessWidget {
  const AiCeoOfficeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: 'AI대표',
            subtitle:
                '전체 사업을 총괄 판단하는 AI 대표입니다. '
                '각 사업부·AI부서 보고를 종합해 수익성·진행·문제·다음 행동을 판단하고 '
                '대표에게 최종 보고합니다.',
            badge: '소통AI대표부 · 24시간 관제',
            trailing: _LiveStatusBadge(),
          ),
          const SizedBox(height: 20),
          const _SystemPulsePanel(),
          const SizedBox(height: 24),
          const _SummaryStrip(),
          const SizedBox(height: 28),
          const ControlSectionTitle(
            title: 'AI대표 핵심 카드',
            subtitle: '브리핑 · 승인 · 매출 · 고객대응 · 홍보 · 세무 · 전략',
          ),
          _AdaptiveGrid(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 245,
            children: AiControlCenterData.officeCards
                .map((card) => _OfficeInfoCard(card: card))
                .toList(),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 920;
              final approval = _ApprovalQueueCard(
                tasks: AiControlCenterData.approvalTasks,
              );
              final divisions = _DivisionWatchCard(
                statuses: AiControlCenterData.divisionStatuses,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: approval),
                    const SizedBox(width: 16),
                    Expanded(child: divisions),
                  ],
                );
              }

              return Column(
                children: [approval, const SizedBox(height: 16), divisions],
              );
            },
          ),
        ],
      ),
    );
  }
}

class AiStrategyMeetingScreen extends StatelessWidget {
  const AiStrategyMeetingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final meeting = AiControlCenterData.strategyMeeting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHero(
            title: 'AI전략회의실',
            subtitle:
                'AI대표와 각 AI부서장이 현재 사업 운영 안건을 검토하고 찬성·반대·주의 의견을 모아 '
                '대표 승인 여부를 제안하는 회의 화면입니다.',
            badge: meeting.weekLabel,
            trailing: const _LiveStatusBadge(compact: true),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 주 핵심 안건',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    meeting.coreAgenda,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: ControlColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: meeting.agendaExamples
                        .map((agenda) => _SoftChip(label: agenda))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const ControlSectionTitle(
            title: '각 AI부서 의견 카드',
            subtitle: '참석 AI 역할별 찬성 / 반대 / 주의 의견',
          ),
          _AdaptiveGrid(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 230,
            children: meeting.opinions
                .map((opinion) => _StrategyOpinionCard(opinion: opinion))
                .toList(),
          ),
          const SizedBox(height: 28),
          _MeetingDecisionPanel(meeting: meeting),
        ],
      ),
    );
  }
}

class AiIdeaMeetingScreen extends StatelessWidget {
  const AiIdeaMeetingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: 'AI아이디어회의실',
            subtitle:
                '새로운 사업 아이디어를 시장성, 개발 난이도, 수익성, 경쟁 강도, 소통웨어 연관성 기준으로 평가합니다.',
            badge: '신규 사업 아이디어 평가 · 더미데이터',
            trailing: _LiveStatusBadge(compact: true),
          ),
          const SizedBox(height: 24),
          const ControlSectionTitle(
            title: '신규 사업 아이디어 목록',
            subtitle: 'AI부서별 평가 의견과 AI대표 최종 판단',
          ),
          _AdaptiveGrid(
            maxCrossAxisExtent: 430,
            mainAxisExtent: 430,
            children: AiControlCenterData.ideaProposals
                .map((proposal) => _IdeaProposalCard(proposal: proposal))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class AiNotificationCenterScreen extends StatelessWidget {
  const AiNotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = AiControlCenterData.notifications;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: '알림센터',
            subtitle:
                '긴급, 승인 필요, 개발 완료, 고객 문의, 매출, 다운로드, 마케팅, 세무, 투자, 시스템 오류 알림을 한곳에서 확인합니다.',
            badge: 'AI대표 알림 큐 · 승인/보류 처리',
            trailing: _NotificationCountBadge(),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AiNotificationType.values
                .map((type) => _SoftChip(label: type.label))
                .toList(),
          ),
          const SizedBox(height: 28),
          _AdaptiveGrid(
            maxCrossAxisExtent: 520,
            mainAxisExtent: 255,
            children: notifications
                .map(
                  (notification) =>
                      _NotificationCard(notification: notification),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class AiExecutiveWorkspaceScreen extends StatelessWidget {
  const AiExecutiveWorkspaceScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final reports = AiControlCenterData.officeCards.take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHero(
            title: title,
            subtitle: description,
            badge: 'AI대표 하위 업무실 · 확장 예정',
            trailing: Icon(icon, color: ControlColors.teal, size: 36),
          ),
          const SizedBox(height: 24),
          const _SystemPulsePanel(compact: true),
          const SizedBox(height: 28),
          ControlSectionTitle(
            title: '$title 처리 대기',
            subtitle:
                '현재는 더미데이터이며 향후 OpenAI, Firebase, Cloud Functions와 연결됩니다.',
          ),
          _AdaptiveGrid(
            maxCrossAxisExtent: 400,
            mainAxisExtent: 210,
            children: reports
                .map(
                  (report) => _ExecutiveReportCard(
                    report: AiExecutiveReport(
                      title: report.title,
                      department: report.department,
                      summary: report.summary,
                      status: report.status,
                      generatedAt: AiControlCenterData.lastAutoCheckTime,
                      priority: report.status == AiSystemStatus.approvalRequired
                          ? '높음'
                          : '보통',
                      tags: [title, report.department],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class AiDepartmentControlScreen extends StatelessWidget {
  const AiDepartmentControlScreen({super.key, required this.departmentId});

  final String departmentId;

  @override
  Widget build(BuildContext context) {
    final department = AiControlCenterData.departments.firstWhere(
      (item) => item.id == departmentId,
      orElse: () => AiControlCenterData.departments.first,
    );
    final notifications = AiControlCenterData.notifications
        .where((item) => item.department == department.name)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHero(
            title: department.name,
            subtitle: department.summary,
            badge: department.leaderRole,
            trailing: _ProgressBadge(percent: department.progressPercent),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '소통총관제 내 역할',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      AiStatusBadge(status: department.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: department.progressPercent / 100,
                      backgroundColor: ControlColors.slate,
                      color: _statusColor(department.status),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoLine(label: '다음 작업', value: department.nextAction),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          ..._buildDepartmentSections(context, department),
          const SizedBox(height: 28),
          ControlSectionTitle(
            title: 'AI가 감시 중인 업무',
            subtitle: '${department.monitoredWorks.length}개 · 자동 보고 대기 포함',
          ),
          _AdaptiveGrid(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 165,
            children: department.monitoredWorks
                .map(
                  (work) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.visibility_outlined,
                            color: ControlColors.teal,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            work,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          const AiStatusBadge(
                            status: AiSystemStatus.monitoring,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          if (notifications.isNotEmpty) ...[
            const SizedBox(height: 28),
            ControlSectionTitle(title: '관련 알림', subtitle: '부서별 알림 큐'),
            _AdaptiveGrid(
              maxCrossAxisExtent: 520,
              mainAxisExtent: 245,
              children: notifications
                  .map(
                    (notification) =>
                        _NotificationCard(notification: notification),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildDepartmentSections(
    BuildContext context,
    AiDepartment department,
  ) {
    switch (departmentId) {
      case 'productdev':
        return [
          const ControlSectionTitle(
            title: '상품 등록 프로세스',
            subtitle: '기획·구성 → 개발 → 검수 → 등록 → 배포 → 운영',
          ),
          const _ProductRegistrationFlowBar(),
          const SizedBox(height: 16),
          ...AiControlCenterData.productRegistrationPipeline.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductRegistrationCard(item: item),
            ),
          ),
          const SizedBox(height: 20),
          ControlSectionTitle(
            title: '등록 완료 상품 카탈로그',
            subtitle:
                '${AiControlCenterData.registeredProducts.length}개 등록 · 버전·채널·상태 관리',
          ),
          ...AiControlCenterData.registeredProducts.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RegisteredProductCard(product: p),
            ),
          ),
          const SizedBox(height: 20),
          const ControlSectionTitle(
            title: '유지보수 관리',
            subtitle: '버전 · 건강도 · 이슈 · 예정 업데이트 · 점검 일정',
          ),
          ...AiControlCenterData.productMaintenanceRegistry.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductMaintenanceCard(record: record),
            ),
          ),
          const SizedBox(height: 20),
          const ControlSectionTitle(
            title: '사업부별 상품·AI·기술 구성',
            subtitle: '각 소통사업부 진행 상품에 활용 가능한 AI·기술과 추가 구성안',
          ),
          ...AiControlCenterData.divisionProductGuides.map(
            (guide) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _DivisionProductDevCard(guide: guide),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: ControlColors.tealSoft.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.sync_alt,
                        color: ControlColors.teal,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '상품 구성 → 실행 연결',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _InfoLine(
                    label: '→ AI지시진행부',
                    value: '등록·유지보수 작업을 개발·배포·실행 지시로 전달',
                  ),
                  const _InfoLine(
                    label: '→ AI전략부',
                    value: '상품 확장 방향·수익 연결 전략 반영',
                  ),
                  const _InfoLine(
                    label: '→ AI기획.아이디어부',
                    value: '신규 상품 아이디어·우선순위 피드백',
                  ),
                ],
              ),
            ),
          ),
        ];
      case 'workorder':
        return [
          _TaskStatusSection(
            title: '오늘 해야 할 일',
            items: department.monitoredWorks.take(2).toList(),
            status: AiSystemStatus.approvalRequired,
          ),
          const SizedBox(height: 16),
          _TaskStatusSection(
            title: '진행 중 작업',
            items: ['소통여행 APK·프로모 연결', 'GitHub Pages 배포 파이프라인'],
            status: AiSystemStatus.monitoring,
          ),
          const SizedBox(height: 16),
          _TaskStatusSection(
            title: '지연 작업',
            items: ['소통사매앱 데이터 구조', '다운로드센터 경로 점검'],
            status: AiSystemStatus.warning,
          ),
        ];
      case 'strategy':
        final meeting = AiControlCenterData.strategyMeeting;
        return [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '장기 성장 전략',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  _InfoLine(label: '핵심 안건', value: meeting.coreAgenda),
                  _InfoLine(label: '예상 효과', value: meeting.expectedEffect),
                  _InfoLine(label: 'AI대표 제안', value: meeting.finalProposal),
                ],
              ),
            ),
          ),
        ];
      case 'idea':
        return [
          ControlSectionTitle(
            title: '신규 아이디어 평가',
            subtitle: '우선순위 · 개발 가능성 · 수익화 가능성',
          ),
          _AdaptiveGrid(
            maxCrossAxisExtent: 430,
            mainAxisExtent: 380,
            children: AiControlCenterData.ideaProposals
                .take(4)
                .map((p) => _IdeaProposalCard(proposal: p))
                .toList(),
          ),
        ];
      case 'marketing':
        return [
          const ControlSectionTitle(
            title: 'AI홍보.마케팅부 업무',
            subtitle: '홍보 · 마케팅 · 온라인 고객대응 관리',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final promo = _MarketingRoleCard(
                title: '홍보 · 마케팅',
                icon: Icons.campaign_outlined,
                items: const [
                  '각 앱·사업부별 홍보 전략',
                  '프로모 사이트 · GitHub Pages 관리',
                  '유튜브 · 블로그 · 카카오 · 검색 노출',
                  '다운로드 · 홍보 · 배포 링크 정리',
                ],
              );
              final customer = _MarketingRoleCard(
                title: '온라인 고객 대응',
                icon: Icons.support_agent_outlined,
                items: const [
                  '온라인 고객 문의 대응',
                  '고객 상담 내용 정리',
                  '요청 · 불만 · 개선 의견 관리',
                  '반복 문의 FAQ 정리',
                  '고객 반응 분석',
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: promo),
                    const SizedBox(width: 14),
                    Expanded(child: customer),
                  ],
                );
              }
              return Column(
                children: [promo, const SizedBox(height: 14), customer],
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '고객 대응 채널',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _SoftChip(label: '스마트스토어'),
                      _SoftChip(label: '앱 사용자'),
                      _SoftChip(label: '콘텐츠 구매자'),
                      _SoftChip(label: '전자책 구매자'),
                      _SoftChip(label: '자동화 사업 문의'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _InfoLine(label: '미응답', value: '6건 · 긴급 2건 우선 응대'),
                  const _InfoLine(
                    label: '상담 정리',
                    value: '앱 기능 · 견적 · 구매 후기 · 개선 요청 분류 중',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: ControlColors.tealSoft.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.sync_alt,
                        color: ControlColors.teal,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '고객 피드백 전달',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _InfoLine(
                    label: '→ AI전략부',
                    value: '고객 반응·시장 신호·수익 전환 인사이트',
                  ),
                  const _InfoLine(
                    label: '→ AI기획.아이디어부',
                    value: '개선 의견·신규 요청·아이디어 후보',
                  ),
                ],
              ),
            ),
          ),
        ];
      case 'tax':
        return [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '수익·세무 관리',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const _InfoLine(
                    label: '수익 분류',
                    value: '앱 · 전자책 · 광고 · 스마트스토어 · B2B',
                  ),
                  const _InfoLine(label: '세금', value: '부가세 · 종합소득세 · 사업자별 매출'),
                  const _InfoLine(
                    label: '준비',
                    value: '비용·예산·투자 체크 → 홈택스 신고 보조',
                  ),
                ],
              ),
            ),
          ),
        ];
      default:
        return [];
    }
  }
}

class _MarketingRoleCard extends StatelessWidget {
  const _MarketingRoleCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: ControlColors.teal, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(color: ControlColors.teal),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductRegistrationFlowBar extends StatelessWidget {
  const _ProductRegistrationFlowBar();

  @override
  Widget build(BuildContext context) {
    final stages = AiControlCenterData.productRegistrationStages;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: ControlColors.border,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: ControlColors.tealSoft,
                    child: Text(
                      '${stages[i].order}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ControlColors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(stages[i].label, style: labelStyle),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductRegistrationCard extends StatelessWidget {
  const _ProductRegistrationCard({required this.item});

  final ProductRegistrationItem item;

  @override
  Widget build(BuildContext context) {
    final stages = AiControlCenterData.productRegistrationStages;
    final stageIndex = stages.indexOf(item.currentStage);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.divisionName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ControlColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _SoftChip(label: item.currentStage.label),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.summary,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: (stageIndex + 1) / stages.length,
                backgroundColor: ControlColors.slate,
                color: ControlColors.teal,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '등록 체크리스트',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ...item.checklist.asMap().entries.map(
              (entry) {
                final done = entry.key < stageIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color: done
                            ? ControlColors.teal
                            : ControlColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _InfoLine(label: '담당', value: item.owner),
            _InfoLine(label: '갱신', value: item.updatedAt),
          ],
        ),
      ),
    );
  }
}

class _RegisteredProductCard extends StatelessWidget {
  const _RegisteredProductCard({required this.product});

  final RegisteredProduct product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AiStatusBadge(status: product.status, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            _InfoLine(label: '카탈로그 ID', value: product.catalogId),
            _InfoLine(label: '버전', value: product.version),
            _InfoLine(label: '사업부', value: product.divisionName),
            _InfoLine(label: '유형', value: product.productType),
            _InfoLine(label: '등록일', value: product.registeredAt),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: product.channels
                  .map((c) => _SoftChip(label: c))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductMaintenanceCard extends StatelessWidget {
  const _ProductMaintenanceCard({required this.record});

  final ProductMaintenanceRecord record;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontSize: 12);

    Color healthColor;
    if (record.healthScore >= 85) {
      healthColor = ControlColors.teal;
    } else if (record.healthScore >= 70) {
      healthColor = ControlColors.accentWarm;
    } else {
      healthColor = ControlColors.accentRose;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.productName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: healthColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '건강도 ${record.healthScore}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: healthColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoLine(label: '버전', value: record.currentVersion),
            _InfoLine(label: '사업부', value: record.divisionName),
            _InfoLine(label: '최근 점검', value: record.lastCheckedAt),
            const SizedBox(height: 10),
            Text('유지보수 작업', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ...record.maintenanceTasks.map(
              (t) => Text('• $t', style: bodyStyle),
            ),
            const SizedBox(height: 8),
            Text('예정 업데이트', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ...record.scheduledUpdates.map(
              (u) => Text('• $u', style: bodyStyle),
            ),
            if (record.knownIssues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '알려진 이슈',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: ControlColors.accentRose,
                ),
              ),
              const SizedBox(height: 4),
              ...record.knownIssues.map(
                (issue) => Text(
                  '• $issue',
                  style: bodyStyle?.copyWith(color: ControlColors.accentRose),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _InfoLine(label: '다음 유지보수', value: record.nextMaintenanceAction),
          ],
        ),
      ),
    );
  }
}

class _DivisionProductDevCard extends StatelessWidget {
  const _DivisionProductDevCard({required this.guide});

  final DivisionProductDevGuide guide;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.4);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.business_outlined,
                  color: ControlColors.teal,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    guide.divisionName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoLine(label: '현재 상품', value: guide.currentProducts),
            _InfoLine(label: '개발 초점', value: guide.developmentFocus),
            const SizedBox(height: 12),
            Text(
              '활용 AI · 기술',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...guide.recommendations.map(
              (rec) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: rec.category == 'AI'
                      ? ControlColors.tealSoft.withValues(alpha: 0.4)
                      : ControlColors.slate.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SoftChip(label: rec.category),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            rec.aiOrTech,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        _SoftChip(label: '활용 ${rec.utility}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(rec.feature, style: bodyStyle),
                    Text(
                      rec.application,
                      style: bodyStyle?.copyWith(
                        color: ControlColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '추가 상품 구성',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...guide.productEnhancements.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(color: ControlColors.teal),
                    ),
                    Expanded(child: Text(item, style: bodyStyle)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _InfoLine(label: '다음 액션', value: guide.nextProductAction),
          ],
        ),
      ),
    );
  }
}

class _TaskStatusSection extends StatelessWidget {
  const _TaskStatusSection({
    required this.title,
    required this.items,
    required this.status,
  });

  final String title;
  final List<String> items;
  final AiSystemStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                AiStatusBadge(status: status, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(color: ControlColors.teal),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiStatusBadge extends StatelessWidget {
  const AiStatusBadge({super.key, required this.status, this.compact = false});

  final AiSystemStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: compact ? 12 : 14, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveGrid extends StatelessWidget {
  const _AdaptiveGrid({
    required this.children,
    required this.maxCrossAxisExtent,
    required this.mainAxisExtent,
  });

  final List<Widget> children;
  final double maxCrossAxisExtent;
  final double mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            ((constraints.maxWidth / maxCrossAxisExtent).floor())
                .clamp(1, 4)
                .toInt();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: mainAxisExtent,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class _LiveStatusBadge extends StatelessWidget {
  const _LiveStatusBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.circle, color: ControlColors.accentGreen, size: 8),
              SizedBox(width: 6),
              Text(
                'LIVE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ControlColors.accentGreen,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            const Text(
              AiControlCenterData.systemMode,
              style: TextStyle(
                fontSize: 12,
                color: ControlColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SystemPulsePanel extends StatelessWidget {
  const _SystemPulsePanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('24시간 시스템 상태', '정상 감시 중', AiSystemStatus.monitoring),
      (
        '마지막 자동 점검 시간',
        AiControlCenterData.lastAutoCheckTime,
        AiSystemStatus.completed,
      ),
      (
        '다음 자동 점검 예정 시간',
        AiControlCenterData.nextAutoCheckTime,
        AiSystemStatus.automaticReportPending,
      ),
      (
        '자동 보고 대기',
        '${AiControlCenterData.automaticReportQueue}건',
        AiSystemStatus.automaticReportPending,
      ),
      (
        '알림 대기',
        '${AiControlCenterData.notificationQueue}건',
        AiSystemStatus.notificationPending,
      ),
      (
        '승인 필요',
        '${AiControlCenterData.approvalRequiredCount}건',
        AiSystemStatus.approvalRequired,
      ),
      (
        '실행 완료',
        '${AiControlCenterData.completedTodayCount}건',
        AiSystemStatus.completed,
      ),
      ('실패/주의', '${AiControlCenterData.warningCount}건', AiSystemStatus.warning),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('24시간 운영 상태', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items
                  .take(compact ? 5 : items.length)
                  .map(
                    (item) => Container(
                      width: compact ? 190 : 210,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ControlColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ControlColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AiStatusBadge(status: item.$3, compact: true),
                          const SizedBox(height: 10),
                          Text(
                            item.$1,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: ControlColors.textMuted,
                                  fontSize: 11,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$2,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip();

  @override
  Widget build(BuildContext context) {
    final revenue = AiControlCenterData.revenueSummary;
    final download = AiControlCenterData.downloadSummary;
    final inquiry = AiControlCenterData.customerInquirySummary;
    final items = [
      (
        '오늘 매출',
        revenue.todayRevenue,
        '${revenue.orderCount}건 · ${revenue.topSource}',
        Icons.paid_outlined,
        ControlColors.accentGreen,
      ),
      (
        '다운로드',
        '${download.todayDownloads}회',
        '${download.mostDownloaded} · ${download.trend}',
        Icons.download_for_offline_outlined,
        ControlColors.sandBeige,
      ),
      (
        '고객 문의',
        '미응답 ${inquiry.unansweredCount}건',
        '${inquiry.topCategory} · 긴급 ${inquiry.urgentCount}건',
        Icons.support_agent_outlined,
        ControlColors.accentWarm,
      ),
    ];

    return _AdaptiveGrid(
      maxCrossAxisExtent: 420,
      mainAxisExtent: 155,
      children: items
          .map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.$5.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.$4, color: item.$5),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.$1,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$3,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _OfficeInfoCard extends StatelessWidget {
  const _OfficeInfoCard({required this.card});

  final AiOfficeDashboardCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AiStatusBadge(status: card.status, compact: true),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              card.value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: ControlColors.deepNavy,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                card.summary,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            _SoftChip(label: card.department, compact: true),
          ],
        ),
      ),
    );
  }
}

class _ApprovalQueueCard extends StatelessWidget {
  const _ApprovalQueueCard({required this.tasks});

  final List<AiApprovalTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('승인 대기 업무', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        AiStatusBadge(status: task.status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.reason,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _SoftChip(label: task.department, compact: true),
                        _SoftChip(label: task.dueLabel, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DivisionWatchCard extends StatelessWidget {
  const _DivisionWatchCard({required this.statuses});

  final List<BusinessDivisionStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI가 감시 중인 사업부',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            ...statuses.map(
              (status) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            status.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${status.healthScore}점',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      status.status,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '수익 신호: ${status.revenueSignal}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ControlColors.teal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '다음: ${status.nextAction}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrategyOpinionCard extends StatelessWidget {
  const _StrategyOpinionCard({required this.opinion});

  final AiStrategyOpinion opinion;

  @override
  Widget build(BuildContext context) {
    final color = _stanceColor(opinion.stance);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    opinion.department,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StanceBadge(stance: opinion.stance),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              opinion.role,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: ControlColors.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              opinion.opinion,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                opinion.reason,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ControlColors.textPrimary,
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingDecisionPanel extends StatelessWidget {
  const _MeetingDecisionPanel({required this.meeting});

  final AiStrategyMeeting meeting;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '예상 효과 · 비용 · 리스크',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _InfoLine(label: '예상 효과', value: meeting.expectedEffect),
            _InfoLine(label: '예상 비용', value: meeting.expectedCost),
            _InfoLine(label: '리스크', value: meeting.risk),
            const Divider(height: 30),
            Text('AI대표 최종 제안', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              meeting.finalProposal,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('대표 승인'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('보류'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('재검토 요청'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IdeaProposalCard extends StatelessWidget {
  const _IdeaProposalCard({required this.proposal});

  final AiIdeaProposal proposal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    proposal.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _ScoreBadge(score: proposal.marketScore),
              ],
            ),
            const SizedBox(height: 14),
            _ScoreBar(label: '시장성 점수', score: proposal.marketScore),
            const SizedBox(height: 12),
            _InfoLine(label: '개발 난이도', value: proposal.developmentDifficulty),
            _InfoLine(
              label: '예상 개발 기간',
              value: proposal.estimatedDevelopmentPeriod,
            ),
            _InfoLine(label: '예상 수익성', value: proposal.expectedProfitability),
            _InfoLine(label: '경쟁 강도', value: proposal.competitionIntensity),
            _InfoLine(label: '소통웨어 연관성', value: proposal.sotongwareFit),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: proposal.departmentOpinions
                  .take(3)
                  .map((opinion) => _SoftChip(label: opinion, compact: true))
                  .toList(),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _SoftChip(label: 'AI대표: ${proposal.finalJudgement}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _DecisionAction(
                  label: '지금 실행',
                  selected: proposal.finalJudgement == '지금 실행',
                ),
                _DecisionAction(
                  label: '3개월 후 검토',
                  selected: proposal.finalJudgement == '3개월 후 검토',
                ),
                _DecisionAction(label: '보류'),
                _DecisionAction(label: '폐기'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final AiNotification notification;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    notification.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AiStatusBadge(status: notification.status, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SoftChip(label: notification.type.label, compact: true),
                _SoftChip(label: notification.department, compact: true),
                _SoftChip(
                  label: '중요도 ${notification.importance}',
                  compact: true,
                ),
                _SoftChip(label: notification.occurredAt, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                notification.detail,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.travel_explore_rounded, size: 16),
                  label: const Text('결과 링크 열기'),
                ),
                FilledButton.tonal(onPressed: () {}, child: const Text('승인')),
                OutlinedButton(onPressed: () {}, child: const Text('보류')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutiveReportCard extends StatelessWidget {
  const _ExecutiveReportCard({required this.report});

  final AiExecutiveReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AiStatusBadge(status: report.status, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${report.department} · ${report.generatedAt} · 중요도 ${report.priority}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ControlColors.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                report.summary,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: report.tags
                  .map((tag) => _SoftChip(label: tag, compact: true))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: ControlColors.teal),
          ),
          const Text(
            '관제 진행률',
            style: TextStyle(fontSize: 11, color: ControlColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _NotificationCountBadge extends StatelessWidget {
  const _NotificationCountBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${AiControlCenterData.notifications.length}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: ControlColors.accentRose,
            ),
          ),
          const Text(
            '알림 대기',
            style: TextStyle(fontSize: 11, color: ControlColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ControlColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: ControlColors.sandLight.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ControlColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          color: ControlColors.sandBeige,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StanceBadge extends StatelessWidget {
  const _StanceBadge({required this.stance});

  final AiOpinionStance stance;

  @override
  Widget build(BuildContext context) {
    final color = _stanceColor(stance);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        stance.label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ControlColors.tealSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$score점',
        style: const TextStyle(
          color: ControlColors.teal,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text('$score/100', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: score / 100,
            backgroundColor: ControlColors.slate,
            color: score >= 80 ? ControlColors.accentGreen : ControlColors.teal,
          ),
        ),
      ],
    );
  }
}

class _DecisionAction extends StatelessWidget {
  const _DecisionAction({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? ControlColors.tealSoft : ControlColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? ControlColors.teal : ControlColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: selected ? ControlColors.teal : ControlColors.textMuted,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: ControlColors.accentGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(AiSystemStatus status) {
  switch (status) {
    case AiSystemStatus.monitoring:
      return ControlColors.teal;
    case AiSystemStatus.automaticReportPending:
      return ControlColors.sandBeige;
    case AiSystemStatus.notificationPending:
      return const Color(0xFF7C3AED);
    case AiSystemStatus.approvalRequired:
      return ControlColors.accentWarm;
    case AiSystemStatus.completed:
      return ControlColors.accentGreen;
    case AiSystemStatus.warning:
      return ControlColors.accentRose;
    case AiSystemStatus.failed:
      return const Color(0xFFB91C1C);
  }
}

IconData _statusIcon(AiSystemStatus status) {
  switch (status) {
    case AiSystemStatus.monitoring:
      return Icons.visibility_outlined;
    case AiSystemStatus.automaticReportPending:
      return Icons.schedule_send_outlined;
    case AiSystemStatus.notificationPending:
      return Icons.notifications_active_outlined;
    case AiSystemStatus.approvalRequired:
      return Icons.approval_outlined;
    case AiSystemStatus.completed:
      return Icons.check_circle_outline;
    case AiSystemStatus.warning:
      return Icons.warning_amber_outlined;
    case AiSystemStatus.failed:
      return Icons.error_outline;
  }
}

Color _stanceColor(AiOpinionStance stance) {
  switch (stance) {
    case AiOpinionStance.approve:
      return ControlColors.accentGreen;
    case AiOpinionStance.oppose:
      return ControlColors.accentRose;
    case AiOpinionStance.caution:
      return ControlColors.accentWarm;
  }
}
