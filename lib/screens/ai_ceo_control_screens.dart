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
            title: 'AI대표실',
            subtitle:
                '대표 1명이 전체 사업을 24시간 관제하는 비공개 본사 시스템 컨셉입니다. '
                'AI대표가 사업부·관리부서·매출·다운로드·고객문의·승인 업무를 요약합니다.',
            badge: '24시간 AI 경영 관제 · 대표 메인 화면',
            trailing: _LiveStatusBadge(),
          ),
          const SizedBox(height: 20),
          const _SystemPulsePanel(),
          const SizedBox(height: 24),
          const _SummaryStrip(),
          const SizedBox(height: 28),
          const ControlSectionTitle(
            title: 'AI대표실 핵심 카드',
            subtitle: '오늘의 브리핑 · 알림 · 승인 · 매출 · 고객문의 · 개발/마케팅/재무/투자 상태',
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
                          '24시간 부서 관제 상태',
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
          ControlSectionTitle(
            title: 'AI가 감시 중인 업무 목록',
            subtitle:
                '${department.monitoredWorks.length}개 업무 · 자동 보고 대기 상태 포함',
          ),
          _AdaptiveGrid(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 150,
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
          const SizedBox(height: 28),
          ControlSectionTitle(
            title: '관련 알림',
            subtitle: notifications.isEmpty
                ? '현재 표시할 전용 알림은 없습니다.'
                : '부서별 알림 큐',
          ),
          if (notifications.isEmpty)
            const _EmptyCard(
              message: '현재 이 부서의 긴급 알림은 없습니다. 다음 자동 점검을 기다리는 중입니다.',
            )
          else
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
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('상세보기'),
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
