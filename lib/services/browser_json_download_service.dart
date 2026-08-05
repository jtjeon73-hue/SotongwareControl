import 'browser_json_download_stub.dart'
    if (dart.library.js_interop) 'browser_json_download_web.dart'
    as impl;

export 'browser_json_download.dart';

/// 앱 시작 시 웹 다운로드 구현을 등록한다.
void ensureBrowserJsonDownloadRegistered() => impl.ensureRegistered();
