import 'browser_json_download.dart';

void ensureRegistered() {
  registerBrowserJsonDownload(({required fileName, required jsonText}) {
    // VM/테스트: 실제 파일 없이 호출만 기록 (triggerBrowserJsonDownload가 카운트).
  });
}
