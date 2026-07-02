import 'package:flutter/material.dart';

import '../data/management_hub_data.dart';
import '../theme/control_theme.dart';
import '../widgets/control_section_title.dart';
import '../widgets/page_hero.dart';

class AiRepresentativeScreen extends StatelessWidget {
  const AiRepresentativeScreen({super.key});

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
                '각 사업부·관리부서의 운영 비전을 종합해 전략·수익·리스크·실행을 제안하는 '
                '소통웨어 AI대표 컨셉 데모입니다. (모든 데이터는 샘플·예시)',
            badge: '대표 보좌 · 총괄 관제 · 전략 제안',
          ),
          const SizedBox(height: 24),
          _BriefingCard(),
          const SizedBox(height: 28),
          const ControlSectionTitle(
            title: '사업부별 핵심 진단',
            subtitle: '현황 · 수익 방향 · 발전 방향 · 실행 제안',
          ),
          ...ManagementHubData.divisionBriefs.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DivisionBriefCard(brief: b),
            ),
          ),
          const SizedBox(height: 20),
          const ControlSectionTitle(
            title: '관리부서별 핵심 제안',
            subtitle: '부서 역할 → AI대표 종합 판단',
          ),
          ...ManagementHubData.departmentBriefs.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DepartmentBriefCard(brief: b),
            ),
          ),
          const SizedBox(height: 20),
          const ControlSectionTitle(
            title: '수익 확대 · 리스크 · 다음 실행',
            subtitle: '체크 기반 진행/보류/우선순위 결정으로 확장 예정',
          ),
          ...ManagementHubData.executionProposals.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExecutionCard(proposal: p),
            ),
          ),
          const SizedBox(height: 16),
          _VisionFooter(),
        ],
      ),
    );
  }
}

class _BriefingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ControlColors.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_outlined,
                    color: ControlColors.teal,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '오늘의 AI대표 종합 브리핑',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              ManagementHubData.aiTodayBriefing.trim(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('수익 확대 포인트', ControlColors.accentGreen),
                _chip('운영 리스크 점검', ControlColors.accentWarm),
                _chip('다음 실행 추천', ControlColors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DivisionBriefCard extends StatelessWidget {
  const _DivisionBriefCard({required this.brief});

  final AiDivisionBrief brief;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              brief.divisionName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _line('현재', brief.currentStatus),
            _line('진행', brief.progressSummary),
            _line('수익', brief.revenueDirection),
            _line('발전', brief.growthDirection),
            const SizedBox(height: 10),
            Text('해야 할 일', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            ...brief.recommendedActions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.task_alt,
                      size: 14,
                      color: ControlColors.teal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a,
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

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: ControlColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentBriefCard extends StatelessWidget {
  const _DepartmentBriefCard({required this.brief});

  final AiDepartmentBrief brief;

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
                    brief.departmentName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(
                  Icons.hub_outlined,
                  size: 16,
                  color: ControlColors.sandBeige,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '→ AI대표 종합 입력',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: ControlColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            _line('현황', brief.currentStatus),
            _line('제안', brief.keyProposal),
            _line('보완', brief.riskOrGap),
            const SizedBox(height: 8),
            ...brief.recommendedActions.map(
              (a) =>
                  Text('· $a', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _ExecutionCard extends StatelessWidget {
  const _ExecutionCard({required this.proposal});

  final AiExecutionProposal proposal;

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
                    proposal.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _DecisionChip(label: proposal.suggestedDecision),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              proposal.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '기대 효과: ${proposal.impact}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ControlColors.teal,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _CheckPlaceholder(label: '진행'),
                const SizedBox(width: 8),
                _CheckPlaceholder(label: '보류'),
                const SizedBox(width: 8),
                _CheckPlaceholder(label: '우선', selected: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionChip extends StatelessWidget {
  const _DecisionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ControlColors.tealSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: ControlColors.teal,
        ),
      ),
    );
  }
}

class _CheckPlaceholder extends StatelessWidget {
  const _CheckPlaceholder({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? ControlColors.teal.withValues(alpha: 0.1)
            : ControlColors.slate,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? ControlColors.teal : ControlColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.check_box_outlined : Icons.check_box_outline_blank,
            size: 14,
            color: selected ? ControlColors.teal : ControlColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? ControlColors.teal : ControlColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisionFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ControlColors.border),
      ),
      child: Text(
        ManagementHubData.visionNote,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }
}
