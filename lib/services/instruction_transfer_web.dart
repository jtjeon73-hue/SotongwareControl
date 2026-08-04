import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'instruction_transfer_types.dart';

const _folderNameKey = 'sotong24_transfer_folder_name_v1';

JSObject? _directoryHandle;
String? _folderName;

bool _isSupported() {
  try {
    return web.window.hasProperty('showDirectoryPicker'.toJS).toDart;
  } catch (_) {
    return false;
  }
}

Future<FolderPermissionState> currentState() async {
  final prefs = await SharedPreferences.getInstance();
  _folderName ??= prefs.getString(_folderNameKey);
  final supported = _isSupported();
  var granted = false;
  final handle = _directoryHandle;
  if (handle != null) {
    try {
      final status =
          await (handle.callMethod(
                    'queryPermission'.toJS,
                    [
                      {'mode': 'readwrite'}.jsify(),
                    ].toJS,
                  )
                  as JSPromise)
              .toDart;
      granted = '$status' == 'granted';
    } catch (_) {
      granted = false;
    }
  }
  return FolderPermissionState(
    supported: supported,
    hasHandle: handle != null,
    folderName: _folderName,
    permissionGranted: granted,
  );
}

Future<FolderPermissionState> pickFolder() async {
  if (!_isSupported()) {
    return const FolderPermissionState(supported: false, hasHandle: false);
  }
  try {
    final handle =
        await (web.window.callMethod(
                  'showDirectoryPicker'.toJS,
                  [
                    {'mode': 'readwrite', 'id': 'sotong24work-inbox'}.jsify(),
                  ].toJS,
                )
                as JSPromise<JSObject>)
            .toDart;
    _directoryHandle = handle;
    final nameProp = handle.getProperty('name'.toJS);
    _folderName = nameProp == null ? 'Inbox' : (nameProp as JSString).toDart;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderNameKey, _folderName ?? 'Inbox');
    return FolderPermissionState(
      supported: true,
      hasHandle: true,
      folderName: _folderName,
      permissionGranted: true,
    );
  } catch (_) {
    return FolderPermissionState(
      supported: true,
      hasHandle: _directoryHandle != null,
      folderName: _folderName,
      permissionGranted: false,
    );
  }
}

void _triggerDownload(String fileName, String jsonText) {
  final bytes = Uint8List.fromList(utf8.encode(jsonText));
  final blobParts = [bytes.toJS].toJS;
  final blob = web.Blob(
    blobParts,
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

Future<TransferWriteResult> writeJsonFile({
  required String fileName,
  required String jsonText,
}) async {
  if (!_isSupported()) {
    _triggerDownload(fileName, jsonText);
    return TransferWriteResult(
      ok: true,
      mode: 'download',
      fileName: fileName,
      message:
          '이 브라우저는 폴더 직접 저장을 지원하지 않습니다. 다운로드가 시작되었습니다. '
          r'파일을 Documents\Sotong24Work\Instructions\Inbox 로 옮겨 주세요.',
      errorCode: 'unsupported',
    );
  }

  final handle = _directoryHandle;
  if (handle == null) {
    _triggerDownload(fileName, jsonText);
    return TransferWriteResult(
      ok: true,
      mode: 'download',
      fileName: fileName,
      message:
          '전달 폴더가 선택되지 않아 다운로드로 대체했습니다. '
          r'「전달 폴더 설정」에서 Inbox 폴더를 선택한 뒤 다시 전달하세요.',
      errorCode: 'no_folder',
    );
  }

  try {
    final perm =
        await (handle.callMethod(
                  'requestPermission'.toJS,
                  [
                    {'mode': 'readwrite'}.jsify(),
                  ].toJS,
                )
                as JSPromise)
            .toDart;
    if ('$perm' != 'granted') {
      _triggerDownload(fileName, jsonText);
      return TransferWriteResult(
        ok: true,
        mode: 'download',
        fileName: fileName,
        message: '폴더 권한이 없어 다운로드로 대체했습니다. 권한을 다시 승인해 주세요.',
        errorCode: 'permission_denied',
      );
    }

    final fileHandle =
        await (handle.callMethod(
                  'getFileHandle'.toJS,
                  [
                    fileName.toJS,
                    {'create': true}.jsify(),
                  ].toJS,
                )
                as JSPromise<JSObject>)
            .toDart;
    final writable =
        await (fileHandle.callMethod('createWritable'.toJS)
                as JSPromise<JSObject>)
            .toDart;
    await (writable.callMethod('write'.toJS, [jsonText.toJS].toJS) as JSPromise)
        .toDart;
    await (writable.callMethod('close'.toJS) as JSPromise).toDart;

    return TransferWriteResult(
      ok: true,
      mode: 'folder',
      fileName: fileName,
      message: '전달 폴더「${_folderName ?? ''}」에 저장했습니다.',
    );
  } catch (e) {
    _triggerDownload(fileName, jsonText);
    return TransferWriteResult(
      ok: true,
      mode: 'download',
      fileName: fileName,
      message: '폴더 저장에 실패해 다운로드로 대체했습니다. ($e)',
      errorCode: 'write_failed',
    );
  }
}

Future<String?> readBackFile(String fileName) async {
  final handle = _directoryHandle;
  if (handle == null) return null;
  try {
    final fileHandle =
        await (handle.callMethod('getFileHandle'.toJS, [fileName.toJS].toJS)
                as JSPromise<JSObject>)
            .toDart;
    final file =
        await (fileHandle.callMethod('getFile'.toJS) as JSPromise<JSObject>)
            .toDart;
    final text = await (file.callMethod('text'.toJS) as JSPromise).toDart;
    return text == null ? null : (text as JSString).toDart;
  } catch (_) {
    return null;
  }
}
