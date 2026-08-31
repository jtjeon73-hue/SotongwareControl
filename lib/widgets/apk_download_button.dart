import 'package:flutter/material.dart';

import '../services/apk_download_service.dart';
import '../theme/control_theme.dart';

class ApkDownloadButton extends StatefulWidget {
  const ApkDownloadButton({
    super.key,
    required this.projectId,
    required this.stageId,
    required this.title,
    required this.revision,
    this.presentation,
    this.downloader = const ArtifactApkDownloadService(),
  });

  final String projectId;
  final String stageId;
  final String title;
  final int revision;
  final ApkDownloadPresentation? presentation;
  final ApkDownloader downloader;

  @override
  State<ApkDownloadButton> createState() => _ApkDownloadButtonState();
}

class _ApkDownloadButtonState extends State<ApkDownloadButton> {
  var _busy = false;

  ApkDownloadPresentation get _presentation =>
      widget.presentation ??
      ApkDownloadPresentation(
        appTitle: widget.title,
        sizeLabel: ApkDownloadPresentation.formatSizeLabel(49998528),
      );

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.downloader.downloadApk(
      projectId: widget.projectId,
      stageId: widget.stageId,
      title: widget.title,
      revision: widget.revision,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final info = _presentation;
    return Material(
      color: ControlColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('final_apk_download_button'),
        onTap: _busy ? null : _download,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ControlColors.teal.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.android_outlined,
                        color: ControlColors.teal,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _busy ? 'APK 준비 중…' : 'APK 다운로드',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      info.appTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'Android APK',
                        '버전 ${info.versionName}',
                        if (info.sizeLabel.isNotEmpty) info.sizeLabel,
                      ].join(' · '),
                      style: TextStyle(
                        color: ControlColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${info.reviewLabel} · ${info.storeLabel}',
                      style: TextStyle(
                        color: ControlColors.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_busy)
                Icon(
                  Icons.download_outlined,
                  color: ControlColors.teal,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
