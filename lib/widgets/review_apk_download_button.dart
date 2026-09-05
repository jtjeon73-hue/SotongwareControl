import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/commercial/production_review_status_envelope.dart';
import '../services/apk_download_service.dart';
import '../services/production_review_status_presentation.dart';
import '../services/review_apk_download_service.dart';
import '../theme/control_theme.dart';

/// Review-only APK download (parallel to Golden project-stage download).
class ReviewApkDownloadButton extends StatefulWidget {
  const ReviewApkDownloadButton({
    super.key,
    required this.envelope,
    this.firestore,
  });

  final ProductionReviewStatusEnvelope envelope;
  final FirebaseFirestore? firestore;

  @override
  State<ReviewApkDownloadButton> createState() =>
      _ReviewApkDownloadButtonState();
}

class _ReviewApkDownloadButtonState extends State<ReviewApkDownloadButton> {
  var _busy = false;

  ProductionReviewStatusEnvelope get e => widget.envelope;

  FirebaseFirestore? get _db {
    if (widget.firestore != null) return widget.firestore;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  Future<void> _download(int sizeBytes) async {
    if (_busy) return;
    final rev = e.revisionRank;
    final sha = e.technicalValidation.artifactSha256.trim();
    if (rev < 1 || sha.isEmpty) return;
    setState(() => _busy = true);
    final downloader = ReviewApkDownloadService(
      instructionId: e.instructionId,
      artifactSha256: sha,
    );
    final result = await downloader.downloadApk(
      projectId: e.instructionId,
      stageId: 'review_artifact',
      title: e.displayTitle.isNotEmpty ? e.displayTitle : 'SotongApp',
      revision: rev,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!ProductionReviewStatusPresentation.showReviewApkDownload(e)) {
      return const SizedBox.shrink();
    }
    final db = _db;
    if (db == null) return const SizedBox.shrink();
    final rev = e.revisionRank;
    final docId = '${e.instructionId}__r$rev';
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('sotong24_review_artifacts').doc(docId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data?.exists != true) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.data() ?? const <String, dynamic>{};
        if (data['reviewOnly'] != true) return const SizedBox.shrink();
        final metaSha = '${data['sha256'] ?? ''}'.trim().toLowerCase();
        final expected = e.technicalValidation.artifactSha256
            .trim()
            .toLowerCase();
        if (metaSha.isEmpty || metaSha != expected) {
          return const SizedBox.shrink();
        }
        final sizeBytes = (data['sizeBytes'] is num)
            ? (data['sizeBytes'] as num).toInt()
            : int.tryParse('${data['sizeBytes'] ?? ''}') ?? 0;
        final sizeLabel = ApkDownloadPresentation.formatSizeLabel(sizeBytes);
        final shaShort = expected.length >= 12
            ? '${expected.substring(0, 12)}…'
            : expected;
        return Container(
          key: const Key('review_apk_download_panel'),
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ControlColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ControlColors.teal),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                e.displayTitle.isNotEmpty ? e.displayTitle : e.instructionId,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  e.revision.isNotEmpty ? e.revision : 'R$rev',
                  if (e.userLabelKo.isNotEmpty) e.userLabelKo,
                ].join(' · '),
                style: const TextStyle(
                  color: ControlColors.textSecondary,
                  height: 1.35,
                ),
              ),
              if (sizeLabel.isNotEmpty || shaShort.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (sizeLabel.isNotEmpty) sizeLabel,
                    if (shaShort.isNotEmpty) 'SHA $shaShort',
                  ].join(' · '),
                  style: const TextStyle(
                    color: ControlColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('review_apk_download_button'),
                  onTap: _busy ? null : () => _download(sizeBytes),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ControlColors.teal.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.android_outlined,
                                color: ControlColors.teal,
                                size: 20,
                              ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _busy ? 'APK 준비 중…' : 'APK 다운로드',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!_busy)
                          const Icon(
                            Icons.download_outlined,
                            color: ControlColors.teal,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '검토용 · Play Store 미등록 · 외부 공개 아님',
                style: TextStyle(color: ControlColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}
