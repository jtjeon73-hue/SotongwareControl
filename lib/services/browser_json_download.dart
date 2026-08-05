/// 브라우저 JSON 다운로드 단일 진입점 (Inbox 직접 전달 경로에서는 호출 금지).
library;

/// 테스트·진단용 호출 횟수.
int browserJsonDownloadCallCount = 0;

/// Inbox 직접 전달 진행 중이면 true — 다운로드를 물리적으로 차단한다.
bool browserJsonDownloadBlocked = false;

void resetBrowserJsonDownloadCallCount() {
  browserJsonDownloadCallCount = 0;
}

/// 웹/스텁이 구현하는 실제 다운로드.
typedef BrowserJsonDownloadFn =
    void Function({required String fileName, required String jsonText});

BrowserJsonDownloadFn? _impl;

void registerBrowserJsonDownload(BrowserJsonDownloadFn fn) {
  _impl = fn;
}

/// 수동 가져오기용 다운로드만 이 함수를 통해 실행한다.
void triggerBrowserJsonDownload({
  required String fileName,
  required String jsonText,
}) {
  browserJsonDownloadCallCount++;
  if (browserJsonDownloadBlocked) {
    throw StateError(
      'Inbox 직접 전달 중에는 브라우저 다운로드가 차단됩니다. '
      'downloadCallCount=$browserJsonDownloadCallCount',
    );
  }
  final fn = _impl;
  if (fn == null) {
    throw StateError('브라우저 다운로드 구현이 등록되지 않았습니다.');
  }
  fn(fileName: fileName, jsonText: jsonText);
}
