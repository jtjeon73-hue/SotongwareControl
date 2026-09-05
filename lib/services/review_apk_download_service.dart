import 'apk_download_service.dart';
import 'pdf_download_platform_stub.dart'
    if (dart.library.js_interop) 'pdf_download_platform_web.dart'
    as platform;
import 'pdf_download_service.dart' show isAllowedArtifactDownloadUri;
import 'remote_control_api.dart';

/// Review-only APK downloader (bound to production_review_status SHA/revision).
class ReviewApkDownloadService implements ApkDownloader {
  const ReviewApkDownloadService({
    required this.instructionId,
    required this.artifactSha256,
    this.api,
    this.attachmentOpener,
  });

  final String instructionId;
  final String artifactSha256;
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
    final sha = artifactSha256.trim().toLowerCase();
    if (sha.length != 64) {
      return const ApkDownloadResult(false, '검토용 APK 검증 정보가 없습니다.');
    }
    try {
      final grant = await (api ?? RemoteControlApi())
          .createReviewArtifactDownloadGrant(
            instructionId: instructionId.trim().isNotEmpty
                ? instructionId.trim()
                : projectId.trim(),
            revision: safeRevision,
            artifactSha256: sha,
            downloadFileName: downloadName,
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
    } on RemoteControlApiException catch (e) {
      final detail = e.userMessage.trim();
      if (detail.isEmpty) {
        return const ApkDownloadResult(
          false,
          '검토용 APK를 다운로드하지 못했습니다. 잠시 후 다시 시도해 주세요.',
        );
      }
      return ApkDownloadResult(false, detail);
    } catch (_) {
      return const ApkDownloadResult(
        false,
        '검토용 APK를 다운로드하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }
}
