import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'browser_json_download.dart';

bool _registered = false;

void ensureRegistered() {
  if (_registered) return;
  _registered = true;
  registerBrowserJsonDownload(_download);
}

void _download({required String fileName, required String jsonText}) {
  final bytes = Uint8List.fromList(utf8.encode(jsonText));
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..setAttribute('download', fileName);
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
