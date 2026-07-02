import 'package:flutter/material.dart';
import '../data/promo_sites_data.dart';
import '../models/business_division.dart';
import '../state/control_scope.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';
import '../widgets/app_development_promo_summary.dart';
import '../widgets/app_project_promo_card.dart';
import '../widgets/control_section_title.dart';
import '../widgets/public_demo_notice.dart';

class BusinessDivisionScreen extends StatelessWidget {
  const BusinessDivisionScreen({super.key, required this.division});

  final BusinessDivision division;

  bool get _isAppDevelopment => division.id == 'app_development';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ControlScope.of(context),
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(division: division),
              const SizedBox(height: 16),
              const PublicDemoNotice(compact: true),
              const SizedBox(height: 24),
              if (_isAppDevelopment) ...[
                const AppDevelopmentPromoSummary(),
                const SizedBox(height: 24),
              ],
              if (division.projects.isNotEmpty) ...[
                ControlSectionTitle(
                  title: _isAppDevelopment ? '앱별 프로젝트·프로모' : '프로젝트',
                  subtitle: _isAppDevelopment
                      ? '${division.projects.length}개 앱 · 개별 프로모 URL 연결'
                      : '${division.projects.length}개 앱 프로젝트',
                ),
                _ProjectGrid(
                  projects: division.projects,
                  usePromoCards: _isAppDevelopment,
                ),
                const SizedBox(height: 32),
              ],
              ...division.detailSections.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ControlSectionTitle(title: entry.key),
                      _DetailSectionCard(items: entry.value),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.division});

  final BusinessDivision division;

  @override
  Widget build(BuildContext context) {
    final promoSite = PromoSitesData.promoForDivision(division.id);
    final promoUrl = promoSite != null
        ? ControlScope.of(context).promoUrlFor(promoSite.id)
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ControlColors.charcoal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            division.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            division.detailDescription ?? division.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ControlColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: ControlColors.teal.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              division.status,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: ControlColors.teal),
            ),
          ),
          if (promoSite != null && promoUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final ok = await ExternalUrl.open(promoUrl);
                if (!context.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${promoSite.repoName} 사이트를 열 수 없습니다.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text('${promoSite.displayName} 총괄 홍보사이트 열기'),
              style: FilledButton.styleFrom(
                backgroundColor: ControlColors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: ControlColors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({required this.projects, required this.usePromoCards});

  final List<DivisionProject> projects;
  final bool usePromoCards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;
        final extent = usePromoCards ? 340.0 : 220.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: extent,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            if (usePromoCards) {
              return AppProjectPromoCard(project: project);
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
