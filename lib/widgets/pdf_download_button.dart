import 'package:flutter/material.dart';

import '../services/pdf_download_service.dart';
import '../theme/control_theme.dart';

class PdfDownloadButton extends StatefulWidget {
  const PdfDownloadButton({
    super.key,
    required this.projectId,
    required this.stageId,
    required this.title,
    required this.revision,
    this.downloader = const ArtifactPdfDownloadService(),
  });

  final String projectId;
  final String stageId;
  final String title;
  final int revision;
  final PdfDownloader downloader;

  @override
  State<PdfDownloadButton> createState() => _PdfDownloadButtonState();
}

class _PdfDownloadButtonState extends State<PdfDownloadButton> {
  var _busy = false;

  Future<void> _download() async {
    if (_busy) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    setState(() => _busy = true);
    final result = await widget.downloader.downloadPdf(
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _download,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined, size: 18),
        label: Text(_busy ? 'PDF 준비 중…' : 'PDF 다운로드'),
        style: OutlinedButton.styleFrom(
          foregroundColor: ControlColors.teal,
          side: BorderSide(color: ControlColors.teal.withValues(alpha: 0.45)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
