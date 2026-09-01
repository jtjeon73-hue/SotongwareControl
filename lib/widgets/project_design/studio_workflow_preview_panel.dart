import 'package:flutter/material.dart';

import '../../data/sotong24_workflows.dart';
import '../../models/artifact_type.dart';
import '../../theme/control_theme.dart';

/// STEP E — 18단계 제작계획 미리보기 (Sotong24WorkflowCatalog SSOT).
class StudioWorkflowPreviewPanel extends StatelessWidget {
  const StudioWorkflowPreviewPanel({
    super.key,
    required this.artifactType,
    this.contentSubtype = '',
  });

  final String artifactType;
  final String contentSubtype;

  @override
  Widget build(BuildContext context) {
    final normalized = ArtifactType.normalize(artifactType);
    if (normalized == ArtifactType.undecided) {
      return const Text('제작 유형을 먼저 선택하세요.');
    }

    final workflow = Sotong24WorkflowCatalog.forProduct(
      normalized,
      contentSubtype: contentSubtype,
    );
    final limitedBackend =
        normalized == ArtifactType.site ||
        normalized == ArtifactType.promoSite ||
        normalized == ArtifactType.contents;

    return Card(
      color: ControlColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '18단계 제작계획 미리보기',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              workflow.title,
              style: const TextStyle(
                fontSize: 12.5,
                color: ControlColors.textSecondary,
              ),
            ),
            if (limitedBackend) ...[
              const SizedBox(height: 8),
              const Text(
                '참고: 사이트/콘텐츠는 UI 18단계 미리보기를 제공하며, '
                '백엔드 canonical validator는 ebook/app 대비 제한될 수 있습니다.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: ControlColors.accentWarm,
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (final stage in workflow.stages) _StageTile(stage: stage),
          ],
        ),
      ),
    );
  }
}

class _StageTile extends StatefulWidget {
  const _StageTile({required this.stage});

  final Sotong24WorkflowStageDef stage;

  @override
  State<_StageTile> createState() => _StageTileState();
}

class _StageTileState extends State<_StageTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: ControlColors.tealSoft.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'STEP ${s.order}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                  ],
                ),
                if (_open) ...[
                  const SizedBox(height: 6),
                  _detailRow('목적', s.purpose),
                  _detailRow('주요 산출물', s.outputs),
                  _detailRow('검증 기준', s.qualityChecks.join(' · ')),
                  _detailRow('예상 AI 작업자', s.aiWork),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 12,
            color: ControlColors.textPrimary,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
