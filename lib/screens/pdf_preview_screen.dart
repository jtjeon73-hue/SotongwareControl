import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../services/pdf_download_service.dart';
import '../services/remote_control_api.dart';
import '../theme/control_theme.dart';
import '../widgets/pdf_download_button.dart';

typedef PdfPreviewContentBuilder =
    Widget Function(BuildContext context, Uint8List pdfBytes);
typedef PdfPreviewBytesProvider =
    Future<Uint8List> Function({
      required String projectId,
      required String stageId,
      required int revision,
    });

class PdfPreviewButton extends StatelessWidget {
  const PdfPreviewButton({
    super.key,
    required this.url,
    required this.projectId,
    required this.stageId,
    required this.title,
    required this.revision,
    this.downloader = const ArtifactPdfDownloadService(),
    this.previewBuilder,
    this.bytesProvider,
  });

  final String url;
  final String projectId;
  final String stageId;
  final String title;
  final int revision;
  final PdfDownloader downloader;
  final PdfPreviewContentBuilder? previewBuilder;
  final PdfPreviewBytesProvider? bytesProvider;

  bool get _hasValidUrl {
    final uri = Uri.tryParse(url.trim());
    return uri != null && isAllowedArtifactDownloadUri(uri);
  }

  Future<void> _openPreview(BuildContext context) async {
    if (!_hasValidUrl) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/pdf-preview'),
        builder: (_) => PdfPreviewScreen(
          projectId: projectId,
          stageId: stageId,
          title: title,
          revision: revision,
          downloader: downloader,
          previewBuilder: previewBuilder,
          bytesProvider: bytesProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: _hasValidUrl ? () => _openPreview(context) : null,
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: const Text('PDF 보기'),
        style: FilledButton.styleFrom(
          backgroundColor: ControlColors.tealSoft,
          foregroundColor: ControlColors.teal,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    super.key,
    required this.projectId,
    required this.stageId,
    required this.title,
    required this.revision,
    this.downloader = const ArtifactPdfDownloadService(),
    this.previewBuilder,
    this.bytesProvider,
  });

  final String projectId;
  final String stageId;
  final String title;
  final int revision;
  final PdfDownloader downloader;
  final PdfPreviewContentBuilder? previewBuilder;
  final PdfPreviewBytesProvider? bytesProvider;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late Future<Uint8List> _pdfBytes;

  @override
  void initState() {
    super.initState();
    _pdfBytes = _loadPdf();
  }

  Future<Uint8List> _loadPdf() async {
    final provider = widget.bytesProvider;
    final bytes = provider != null
        ? await provider(
            projectId: widget.projectId,
            stageId: widget.stageId,
            revision: widget.revision,
          )
        : await RemoteControlApi().fetchArtifactPdf(
            projectId: widget.projectId,
            stageId: widget.stageId,
            revision: widget.revision,
          );
    if (!hasPdfSignature(bytes) || !hasPdfEof(bytes)) {
      throw const FormatException('invalid_pdf_bytes');
    }
    return bytes;
  }

  void _retry() {
    setState(() => _pdfBytes = _loadPdf());
  }

  @override
  Widget build(BuildContext context) {
    final safeRevision = widget.revision > 0 ? widget.revision : 1;
    return Scaffold(
      key: const Key('pdf_preview_screen'),
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              'PDF 미리보기 · r$safeRevision',
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: ControlColors.surfaceMuted,
                child: FutureBuilder<Uint8List>(
                  future: _pdfBytes,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 42),
                              const SizedBox(height: 10),
                              const Text('PDF 미리보기를 불러오지 못했습니다.'),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                key: const Key('pdf_preview_retry_button'),
                                onPressed: _retry,
                                icon: const Icon(Icons.refresh),
                                label: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                          key: Key('pdf_preview_loading'),
                        ),
                      );
                    }
                    return widget.previewBuilder?.call(context, bytes) ??
                        PdfViewer.data(
                          bytes,
                          sourceName: buildPdfDownloadFileName(
                            title: widget.title,
                            revision: safeRevision,
                          ),
                          key: const Key('pdf_preview_document'),
                        );
                  },
                ),
              ),
            ),
            Container(
              color: ControlColors.surface,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '손가락으로 스크롤하고 두 손가락으로 확대·축소할 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: ControlColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  PdfDownloadButton(
                    key: const Key('pdf_preview_download_button'),
                    projectId: widget.projectId,
                    stageId: widget.stageId,
                    title: widget.title,
                    revision: safeRevision,
                    downloader: widget.downloader,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
