import 'package:flutter/material.dart';
import '../models/department.dart';
import '../theme/control_theme.dart';
import '../widgets/control_section_title.dart';
import '../widgets/page_hero.dart';
import '../widgets/public_demo_notice.dart';

class DepartmentScreen extends StatelessWidget {
  const DepartmentScreen({super.key, required this.department});

  final Department department;

  bool get _isFinance => department.id == 'finance';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHero(
            title: department.title,
            subtitle: department.headline ?? department.role,
            badge: _isFinance ? '재무·세무 전략 본부' : '관리부서',
            trailing: department.progressPercent > 0
                ? _ProgressBadge(percent: department.progressPercent)
                : null,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('부서 역할', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    department.role,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const PublicDemoNotice(compact: true),
          if (_isFinance) ...[
            const SizedBox(height: 16),
            _FinanceVisionCard(vision: department.futureVision ?? ''),
          ],
          if (department.futureVision != null && !_isFinance) ...[
            const SizedBox(height: 16),
            _AiHubNote(text: department.futureVision!),
          ],
          const SizedBox(height: 28),
          ControlSectionTitle(
            title: '업무 영역',
            subtitle: '${department.taskCards.length}개 관리 카드 · AI대표 연동 예정',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 600
                  ? 2
                  : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: _isFinance ? 155 : 145,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: department.taskCards.length,
                itemBuilder: (context, index) {
                  final card = department.taskCards[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      (_isFinance
                                              ? ControlColors.sandBeige
                                              : ControlColors.teal)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _isFinance
                                      ? Icons.account_balance_outlined
                                      : Icons.work_outline,
                                  size: 16,
                                  color: _isFinance
                                      ? ControlColors.sandBeige
                                      : ControlColors.teal,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  card.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              card.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          const _AiHubNote(
            text: '이 부서의 핵심 데이터는 AI대표 화면에서 종합 브리핑·실행 제안으로 연결됩니다.',
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ControlColors.border),
      ),
      child: Text(
        '진행 $percent%',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: ControlColors.teal,
        ),
      ),
    );
  }
}

class _FinanceVisionCard extends StatelessWidget {
  const _FinanceVisionCard({required this.vision});

  final String vision;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ControlColors.sandLight,
            ControlColors.tealSoft.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.savings_outlined,
                color: ControlColors.sandBeige,
              ),
              const SizedBox(width: 10),
              Text(
                '홈택스 연동 · 재무 자동화 비전',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(vision, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _Tag('홈택스 연동'),
              _Tag('세무 점검'),
              _Tag('재무 리포트'),
              _Tag('재테크·투자'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ControlColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: ControlColors.sandBeige),
      ),
    );
  }
}

class _AiHubNote extends StatelessWidget {
  const _AiHubNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ControlColors.tealSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.teal.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hub_outlined, size: 18, color: ControlColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
