// Browser file pick for operator import. Uses dart:html until package:web
// FileReader result typing is stable across Flutter web SDKs.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

Future<String?> pickExternalWiJsonTextImpl() async {
  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json';
  final completer = Completer<String?>();
  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(reader.result as String?);
      }
    });
    reader.readAsText(files.first);
  });
  input.click();
  return completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () => null,
  );
}
