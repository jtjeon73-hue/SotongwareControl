import 'dart:typed_data';

import 'pdf_download_platform_stub.dart'
    if (dart.library.js_interop) 'pdf_download_platform_web.dart'
    as platform;
import 'remote_control_api.dart';

const String pdfMimeType = 'application/pdf';
const int maxPdfDownloadBytes = 100 * 1024 * 1024;

typedef PdfDownloadGrantProvider =
    Future<PdfDownloadGrant> Function({
      required String projectId,
      required String stageId,
      required int revision,
      required String fileName,
    });
typedef PdfAttachmentOpener = Future<void> Function(String downloadUrl);

abstract interface class PdfDownloader {
  Future<PdfDownloadResult> downloadPdf({
    required String projectId,
    required String stageId,
    required String title,
    required int revision,
  });
}

class PdfDownloadGrant {
  const PdfDownloadGrant({
    required this.downloadUrl,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String downloadUrl;
  final String fileName;
  final String contentType;
  final int sizeBytes;
}

class PdfDownloadResult {
  const PdfDownloadResult._({
    required this.ok,
    required this.fileName,
    required this.sizeBytes,
    required this.message,
  });

  factory PdfDownloadResult.success({
    required String fileName,
    required int sizeBytes,
  }) => PdfDownloadResult._(
    ok: true,
    fileName: fileName,
    sizeBytes: sizeBytes,
    message: '$fileName 다운로드를 시작했습니다.',
  );

  factory PdfDownloadResult.failure(String message) => PdfDownloadResult._(
    ok: false,
    fileName: '',
    sizeBytes: 0,
    message: message,
  );

  final bool ok;
  final String fileName;
  final int sizeBytes;
  final String message;
}

class ArtifactPdfDownloadService implements PdfDownloader {
  const ArtifactPdfDownloadService({this.grantProvider, this.attachmentOpener});

  final PdfDownloadGrantProvider? grantProvider;
  final PdfAttachmentOpener? attachmentOpener;

  @override
  Future<PdfDownloadResult> downloadPdf({
    required String projectId,
    required String stageId,
    required String title,
    required int revision,
  }) async {
    final fileName = buildPdfDownloadFileName(title: title, revision: revision);

    try {
      final grant = await (grantProvider ?? _requestGrant)(
        projectId: projectId,
        stageId: stageId,
        revision: revision,
        fileName: fileName,
      );
      final uri = Uri.tryParse(grant.downloadUrl.trim());
      if (uri == null || !isAllowedArtifactDownloadUri(uri)) {
        return PdfDownloadResult.failure('허용된 전자책 다운로드 URL이 아닙니다.');
      }
      final contentType = grant.contentType
          .split(';')
          .first
          .trim()
          .toLowerCase();
      if (contentType != pdfMimeType) {
        return PdfDownloadResult.failure('PDF 형식이 아닌 응답을 차단했습니다.');
      }
      if (grant.sizeBytes <= 0 || grant.sizeBytes > maxPdfDownloadBytes) {
        return PdfDownloadResult.failure('PDF 파일 크기가 허용 범위를 벗어났습니다.');
      }

      await (attachmentOpener ?? platform.openAttachmentUrl)(grant.downloadUrl);
      return PdfDownloadResult.success(
        fileName: grant.fileName,
        sizeBytes: grant.sizeBytes,
      );
    } catch (_) {
      return PdfDownloadResult.failure('PDF 파일을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }
}

Future<PdfDownloadGrant> _requestGrant({
  required String projectId,
  required String stageId,
  required int revision,
  required String fileName,
}) async {
  final grant = await RemoteControlApi().createArtifactDownloadGrant(
    projectId: projectId,
    stageId: stageId,
    revision: revision,
    fileName: fileName,
  );
  return PdfDownloadGrant(
    downloadUrl: grant.downloadUrl,
    fileName: grant.fileName,
    contentType: grant.contentType,
    sizeBytes: grant.sizeBytes,
  );
}

bool isAllowedArtifactDownloadUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'https' || uri.userInfo.isNotEmpty) {
    return false;
  }
  if (uri.hasPort && uri.port != 443) return false;
  final host = uri.host.toLowerCase();
  const allowedSuffixes = <String>[
    'googleapis.com',
    'firebasestorage.app',
    'googleusercontent.com',
  ];
  return allowedSuffixes.any(
    (suffix) => host == suffix || host.endsWith('.$suffix'),
  );
}

String buildPdfDownloadFileName({
  required String title,
  required int revision,
}) {
  var base = title.trim();
  if (base.toLowerCase().endsWith('.pdf')) {
    base = base.substring(0, base.length - 4);
  }
  base = base
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[._ ]+|[._ ]+$'), '');
  if (base.isEmpty) base = 'AI_전자책_최종본';
  if (base.length > 80) base = base.substring(0, 80);
  final safeRevision = revision < 1 ? 1 : revision;
  return '${base}_r$safeRevision.pdf';
}

bool hasPdfSignature(Uint8List bytes) {
  const signature = <int>[0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}

bool hasPdfEof(Uint8List bytes) {
  const eof = <int>[0x25, 0x25, 0x45, 0x4F, 0x46]; // %%EOF
  if (bytes.length < eof.length) return false;
  final start = bytes.length > 4096 ? bytes.length - 4096 : 0;
  for (var i = bytes.length - eof.length; i >= start; i--) {
    var match = true;
    for (var j = 0; j < eof.length; j++) {
      if (bytes[i + j] != eof[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
