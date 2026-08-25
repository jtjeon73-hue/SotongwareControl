import 'dart:async';

import 'package:web/web.dart' as web;

Future<void> openAttachmentUrl(String downloadUrl) async {
  final anchor = web.HTMLAnchorElement()
    ..href = downloadUrl
    ..setAttribute('rel', 'noopener')
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  try {
    anchor.click();
    // attachment 응답이 브라우저 다운로드 관리자로 인계될 시간을 확보한다.
    await Future<void>.delayed(const Duration(milliseconds: 250));
  } finally {
    anchor.remove();
  }
}
