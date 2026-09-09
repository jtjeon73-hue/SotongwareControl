import 'package:flutter/material.dart';

import '../models/ebook_r1_package_manifest.dart';
import '../models/sotong24_remote_models.dart';
import '../theme/control_theme.dart';

/// 완성형 r1(package_user_review) 결과 요약 + 승인/보완/보류 액션.
class EbookPackageUserReviewPanel extends StatelessWidget {
  const EbookPackageUserReviewPanel({
    super.key,
    required this.project,
    required this.stage,
    required this.busy,
    required this.onApprove,
    required this.onChangesRequested,
    required this.onHold,
    this.manifest,
    this.coverUrl,
    this.onDownloadPdf,
    this.onDownloadEpub,
    this.onPreviewPdf,
    this.onOpenQualityReport,
  });

  final Sotong24RemoteProject project;
  final Sotong24RemoteStage stage;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onChangesRequested;
  final VoidCallback onHold;
  final EbookR1PackageManifest? manifest;
  final String? coverUrl;
  final VoidCallback? onDownloadPdf;
  final VoidCallback? onDownloadEpub;
  final VoidCallback? onPreviewPdf;
  final VoidCallback? onOpenQualityReport;

  @override
  Widget build(BuildContext context) {
    final m = manifest;
    final title = (m?.title.trim().isNotEmpty ?? false)
        ? m!.title
        : project.title;
    final revision = (m?.revision.trim().isNotEmpty ?? false)
        ? m!.revision
        : (stage.revision > 0 ? 'r${stage.revision}' : 'r1');
    final hasPdf = m?.hasDownloadablePdf == true || stage.hasOpenableResult;
    final hasEpub = m?.hasDownloadableEpub == true;
    final score = m?.score;
    final critical = m?.criticalCount ?? 0;
    final major = m?.majorCount ?? 0;
    final refine = m?.refineCount;
    final pass = score != null && score >= 90 && critical == 0 && major == 0;
    final resolvedCoverUrl = (coverUrl ?? m?.coverUrl ?? '').trim();
    final author = (m?.author ?? '').trim();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: ControlColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ControlColors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '완성형 전자책 $revision',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: ControlColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((m?.subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                m!.subtitle,
                style: const TextStyle(color: ControlColors.textSecondary),
              ),
            ],
            if (author.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '저자 · $author',
                style: const TextStyle(
                  fontSize: 13,
                  color: ControlColors.textSecondary,
                ),
              ),
            ],
            if ((m?.generatedAt ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '제작 완료: ${m!.generatedAt}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (resolvedCoverUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    resolvedCoverUrl,
                    height: 160,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      '표지 이미지를 불러오지 못했습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: ControlColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (m?.hasCover == true) ...[
              const SizedBox(height: 8),
              Text(
                'Cover · ${m!.coverPath}',
                style: const TextStyle(
                  fontSize: 12,
                  color: ControlColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('revision $revision'),
                if (score != null) _chip('품질 $score'),
                if (refine != null) _chip('refine $refine'),
                _chip('critical $critical'),
                _chip('major $major'),
                _chip(pass ? 'PASS' : 'CHECK'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '결과물',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (!hasPdf && !hasEpub)
              const Text(
                'artifact가 아직 연결되지 않았습니다. PDF/EPUB/manifest가 필요합니다.',
                style: TextStyle(color: Colors.redAccent),
              )
            else ...[
              if (hasPdf)
                Text(
                  'PDF · ${m?.resolvePdfFileName() ?? 'book.pdf'}'
                  '${(m?.pdfBytes ?? 0) > 0 ? ' · ${_fmtBytes(m!.pdfBytes)}' : ''}',
                ),
              if (hasEpub)
                Text(
                  'EPUB · ${m?.resolveEpubFileName() ?? 'book.epub'}'
                  '${(m?.epubBytes ?? 0) > 0 ? ' · ${_fmtBytes(m!.epubBytes)}' : ''}'
                  '${(m?.epubSha256 ?? '').isNotEmpty ? ' · sha256 ${(m!.epubSha256.length > 12) ? '${m.epubSha256.substring(0, 12)}…' : m.epubSha256}' : ''}',
                ),
              if (m?.frozen == true)
                Text(
                  'immutable · ${m!.immutablePath.isNotEmpty ? m.immutablePath : m.revision}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ControlColors.textSecondary,
                  ),
                ),
              if (m?.hasToc == true) ...[
                const SizedBox(height: 8),
                const Text('목차', style: TextStyle(fontWeight: FontWeight.w700)),
                ...m!.tocSummary
                    .take(8)
                    .map(
                      (line) =>
                          Text(line, style: const TextStyle(fontSize: 12)),
                    ),
              ],
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onPreviewPdf != null && hasPdf)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onPreviewPdf,
                    icon: const Icon(Icons.preview_outlined, size: 18),
                    label: const Text('PDF 미리보기'),
                  ),
                if (onDownloadPdf != null && hasPdf)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onDownloadPdf,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('PDF'),
                  ),
                if (onDownloadEpub != null && hasEpub)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onDownloadEpub,
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('EPUB'),
                  ),
                if (onOpenQualityReport != null)
                  TextButton(
                    onPressed: busy ? null : onOpenQualityReport,
                    child: const Text('품질 보고서'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy || !hasPdf ? null : onApprove,
                  child: const Text('승인'),
                ),
                OutlinedButton(
                  onPressed: busy || !hasPdf ? null : onChangesRequested,
                  child: const Text('보완 요청'),
                ),
                TextButton(
                  onPressed: busy ? null : onHold,
                  child: const Text('보류'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ControlColors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ControlColors.teal,
        ),
      ),
    );
  }

  static String _fmtBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
