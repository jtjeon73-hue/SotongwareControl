import 'pdf_download_platform_stub.dart'
    if (dart.library.js_interop) 'pdf_download_platform_web.dart'
    as platform;
import 'pdf_download_service.dart' show isAllowedArtifactDownloadUri;
import 'remote_control_api.dart';

const String apkMimeType = 'application/vnd.android.package-archive';
const int maxApkDownloadBytes = 200 * 1024 * 1024;

class ApkDownloadResult {
  const ApkDownloadResult(this.ok, this.message);
  final bool ok;
  final String message;
}

abstract interface class ApkDownloader {
  Future<ApkDownloadResult> downloadApk({
    required String projectId,
    required String stageId,
    required String title,
    required int revision,
  });
}

class ArtifactApkDownloadService implements ApkDownloader {
  const ArtifactApkDownloadService({this.api, this.attachmentOpener});
  final RemoteControlApi? api;
  final Future<void> Function(String url)? attachmentOpener;

  @override
  Future<ApkDownloadResult> downloadApk({
    required String projectId,
    required String stageId,
    required String title,
    required int revision,
  }) async {
    final safeRevision = revision < 1 ? 1 : revision;
    final downloadName = buildApkDownloadFileName(title, safeRevision);
    try {
      final grant = await (api ?? RemoteControlApi())
          .createArtifactDownloadGrant(
            projectId: projectId,
            stageId: stageId,
            revision: safeRevision,
            fileName: downloadName,
            productType: 'app',
            artifactFileName: 'app-release_r$safeRevision.apk',
          );
      final uri = Uri.tryParse(grant.downloadUrl.trim());
      final contentType = grant.contentType
          .split(';')
          .first
          .trim()
          .toLowerCase();
      if (uri == null || !isAllowedArtifactDownloadUri(uri)) {
        return const ApkDownloadResult(false, '허용된 APK 다운로드 URL이 아닙니다.');
      }
      if (contentType != apkMimeType) {
        return const ApkDownloadResult(false, 'APK 형식이 아닌 응답을 차단했습니다.');
      }
      if (grant.sizeBytes < 64 * 1024 ||
          grant.sizeBytes > maxApkDownloadBytes) {
        return const ApkDownloadResult(false, 'APK 파일 크기가 허용 범위를 벗어났습니다.');
      }
      await (attachmentOpener ?? platform.openAttachmentUrl)(grant.downloadUrl);
      return ApkDownloadResult(true, '${grant.fileName} 다운로드를 시작했습니다.');
    } catch (_) {
      return const ApkDownloadResult(
        false,
        'APK를 다운로드하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }
}

String buildApkDownloadFileName(String title, int revision) {
  var base = title
      .trim()
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[._ ]+|[._ ]+$'), '');
  if (base.isEmpty) base = 'SotongApp';
  if (base.length > 80) base = base.substring(0, 80);
  return '${base}_r$revision.apk';
}
