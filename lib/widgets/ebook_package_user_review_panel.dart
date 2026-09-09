import 'package:flutter/material.dart';

import '../models/ebook_r1_package_manifest.dart';
import '../models/sotong24_remote_models.dart';
import '../services/remote_control_api.dart';
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
    final author = (m?.author ?? '').trim();
    final coverFileName = () {
      final path = (m?.coverPath ?? '').trim();
      if (path.isEmpty) return '';
      final parts = path.split(RegExp(r'[/\\]'));
      return parts.isNotEmpty ? parts.last.trim() : '';
    }();

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
            if ((coverUrl ?? m?.coverUrl ?? '').trim().isNotEmpty ||
                coverFileName.isNotEmpty) ...[
              const SizedBox(height: 10),
              _EbookCoverGrantPreview(
                projectId: project.projectId,
                stageId: stage.stageId,
                revision: stage.revision > 0 ? stage.revision : 1,
                directUrl: (coverUrl ?? m?.coverUrl ?? '').trim(),
                coverFileName: coverFileName,
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
            ],
            if (m?.hasToc == true) ...[
              const SizedBox(height: 10),
              Text(
                '목차',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              ...m!.tocSummary
                  .take(8)
                  .map(
                    (t) => Text(
                      '· $t',
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onPreviewPdf != null)
                  OutlinedButton(
                    onPressed: busy ? null : onPreviewPdf,
                    child: const Text('PDF 미리보기'),
                  ),
                if (onDownloadPdf != null)
                  OutlinedButton(
                    onPressed: busy ? null : onDownloadPdf,
                    child: const Text('PDF 다운로드'),
                  ),
                if (onDownloadEpub != null)
                  OutlinedButton(
                    onPressed: busy ? null : onDownloadEpub,
                    child: const Text('EPUB 다운로드'),
                  ),
                if (onOpenQualityReport != null)
                  OutlinedButton(
                    onPressed: busy ? null : onOpenQualityReport,
                    child: const Text('품질 보고서 보기'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    child: const Text('승인'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onChangesRequested,
                    child: const Text('보완 요청'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onHold,
                    child: const Text('보류'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ControlColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  String _fmtBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _EbookCoverGrantPreview extends StatefulWidget {
  const _EbookCoverGrantPreview({
    required this.projectId,
    required this.stageId,
    required this.revision,
    required this.directUrl,
    required this.coverFileName,
  });

  final String projectId;
  final String stageId;
  final int revision;
  final String directUrl;
  final String coverFileName;

  @override
  State<_EbookCoverGrantPreview> createState() =>
      _EbookCoverGrantPreviewState();
}

class _EbookCoverGrantPreviewState extends State<_EbookCoverGrantPreview> {
  String? _url;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _EbookCoverGrantPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directUrl != widget.directUrl ||
        oldWidget.coverFileName != widget.coverFileName ||
        oldWidget.revision != widget.revision) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final direct = widget.directUrl.trim();
    if (direct.startsWith('http://') || direct.startsWith('https://')) {
      setState(() {
        _url = direct;
        _error = null;
        _loading = false;
      });
      return;
    }
    if (direct.contains(':\\') || direct.startsWith('\\\\')) {
      setState(() {
        _url = null;
        _error = '로컬 경로는 표지 URL로 사용할 수 없습니다.';
        _loading = false;
      });
      return;
    }
    final name = widget.coverFileName.trim().isNotEmpty
        ? widget.coverFileName.trim()
        : 'cover.png';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final grant = await RemoteControlApi().createArtifactDownloadGrant(
        projectId: widget.projectId,
        stageId: widget.stageId,
        revision: widget.revision,
        fileName: name,
        artifactFileName: name,
      );
      if (!mounted) return;
      setState(() {
        _url = grant.downloadUrl;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _url = null;
        _error = '표지 다운로드 grant 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if ((_url ?? '').isEmpty) {
      return Text(
        _error ?? '표지 이미지를 불러오지 못했습니다.',
        style: const TextStyle(
          fontSize: 12,
          color: ControlColors.textSecondary,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _url!,
          height: 160,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Text(
            '표지 이미지를 불러오지 못했습니다.',
            style: TextStyle(
              fontSize: 12,
              color: ControlColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
