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
    this.downloader = const ArtifactApkDownloadService(),
  });

  final String projectId;
  final String stageId;
  final String title;
  final int revision;
  final ApkDownloader downloader;

  @override
  State<ApkDownloadButton> createState() => _ApkDownloadButtonState();
}

class _ApkDownloadButtonState extends State<ApkDownloadButton> {
  var _busy = false;

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
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      key: const Key('final_apk_download_button'),
      onPressed: _busy ? null : _download,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.android_outlined, size: 18),
      label: Text(_busy ? 'APK 준비 중…' : 'APK 다운로드'),
      style: OutlinedButton.styleFrom(
        foregroundColor: ControlColors.teal,
        side: BorderSide(color: ControlColors.teal.withValues(alpha: 0.45)),
      ),
    ),
  );
}
