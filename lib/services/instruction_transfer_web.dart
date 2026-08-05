import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'instruction_content_checksum.dart';
import 'instruction_transfer_core.dart';
import 'instruction_transfer_types.dart';

const _folderNameKey = 'sotong24_transfer_folder_name_v1';

JSObject? _directoryHandle;
String? _folderName;

JSObject _jsOpts(Map<String, Object> map) {
  final o = JSObject();
  for (final e in map.entries) {
    final v = e.value;
    if (v is bool) {
      o.setProperty(e.key.toJS, v.toJS);
    } else if (v is String) {
      o.setProperty(e.key.toJS, v.toJS);
    } else if (v is num) {
      o.setProperty(e.key.toJS, v.toJS);
    }
  }
  return o;
}

/// DevWorkDoc와 동일: callMethod 인자는 개별 전달 (List.toJS 한 덩어리 금지).
Future<JSAny?> _call0(JSObject target, String method) async {
  return (target.callMethod(method.toJS) as JSPromise).toDart;
}

Future<JSAny?> _call1(JSObject target, String method, JSAny? a1) async {
  return (target.callMethod(method.toJS, a1) as JSPromise).toDart;
}

Future<JSAny?> _call2(
  JSObject target,
  String method,
  JSAny? a1,
  JSAny? a2,
) async {
  return (target.callMethod(method.toJS, a1, a2) as JSPromise).toDart;
}

bool _isSupported() {
  try {
    return web.window.hasProperty('showDirectoryPicker'.toJS).toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> _hasPermission(JSObject handle) async {
  try {
    final status = await _call1(
      handle,
      'queryPermission',
      _jsOpts({'mode': 'readwrite'}),
    );
    return '$status' == 'granted';
  } catch (_) {
    return false;
  }
}

Future<bool> _requestPermission(JSObject handle) async {
  try {
    final status = await _call1(
      handle,
      'requestPermission',
      _jsOpts({'mode': 'readwrite'}),
    );
    return '$status' == 'granted';
  } catch (_) {
    return false;
  }
}

Future<FolderPermissionState> currentState() async {
  final prefs = await SharedPreferences.getInstance();
  _folderName ??= prefs.getString(_folderNameKey);
  final supported = _isSupported();
  final handle = _directoryHandle;
  var granted = false;
  if (handle != null) {
    granted = await _hasPermission(handle);
  }
  return buildInboxFolderState(
    supported: supported,
    hasHandle: handle != null,
    folderName: _folderName,
    permissionGranted: granted,
  );
}

Future<FolderPermissionState> pickFolder() async {
  if (!_isSupported()) {
    return buildInboxFolderState(
      supported: false,
      hasHandle: false,
      permissionGranted: false,
    );
  }
  try {
    final handle =
        await (web.window.callMethod(
                  'showDirectoryPicker'.toJS,
                  _jsOpts({'mode': 'readwrite', 'id': 'sotong24work-inbox'}),
                )
                as JSPromise<JSObject>)
            .toDart;
    final granted = await _requestPermission(handle);
    if (!granted) {
      _directoryHandle = null;
      return buildInboxFolderState(
        supported: true,
        hasHandle: false,
        folderName: _folderName,
        permissionGranted: false,
      );
    }
    _directoryHandle = handle;
    final nameProp = handle.getProperty('name'.toJS);
    _folderName = nameProp == null ? 'Inbox' : (nameProp as JSString).toDart;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderNameKey, _folderName ?? 'Inbox');
    return buildInboxFolderState(
      supported: true,
      hasHandle: true,
      folderName: _folderName,
      permissionGranted: true,
    );
  } catch (_) {
    return buildInboxFolderState(
      supported: true,
      hasHandle: _directoryHandle != null,
      folderName: _folderName,
      permissionGranted: _directoryHandle != null
          ? await _hasPermission(_directoryHandle!)
          : false,
    );
  }
}

/// 수동 가져오기용 — 이 함수만 브라우저 다운로드를 실행한다.
void _triggerManualDownload(String fileName, String jsonText) {
  recordInstructionTransferManualDownloadCall();
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

Future<({String? text, int size})> _readExistingFile(
  JSObject dir,
  String fileName,
) async {
  try {
    final fileHandle =
        await _call1(dir, 'getFileHandle', fileName.toJS) as JSObject;
    final file = await _call0(fileHandle, 'getFile') as JSObject;
    final sizeProp = file.getProperty('size'.toJS);
    final size = sizeProp == null ? 0 : (sizeProp as JSNumber).toDartInt;
    if (size <= 0) return (text: '', size: 0);
    final textJs = await _call0(file, 'text');
    if (textJs == null) return (text: null, size: size);
    return (text: (textJs as JSString).toDart, size: size);
  } catch (_) {
    return (text: null, size: 0);
  }
}

Future<void> _writeUtf8File(
  JSObject dir,
  String fileName,
  String jsonText,
) async {
  final fileHandle =
      await _call2(
            dir,
            'getFileHandle',
            fileName.toJS,
            _jsOpts({'create': true}),
          )
          as JSObject;
  final writable = await _call0(fileHandle, 'createWritable') as JSObject;
  final bytes = Uint8List.fromList(utf8.encode(jsonText));
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  await _call1(writable, 'write', blob);
  await _call0(writable, 'close');
}

/// Inbox 직접 전달. 실패해도 다운로드로 대체하지 않는다.
Future<TransferWriteResult> writeJsonFile({
  required String fileName,
  required String jsonText,
  String? instructionId,
  int? version,
  String? expectedChecksum,
}) async {
  if (!_isSupported()) {
    return TransferWriteResult.failed(
      message:
          '이 브라우저는 폴더 직접 저장을 지원하지 않습니다.\n'
          '다음 행동: 「수동 가져오기용 JSON 다운로드」를 사용하세요.',
      errorCode: 'unsupported',
      fileName: fileName,
    );
  }

  final handle = _directoryHandle;
  if (handle == null) {
    return TransferWriteResult.failed(
      message:
          'Inbox 핸들이 없습니다. 폴더 이름만으로는 전달할 수 없습니다.\n'
          '다음 행동: 「전달 폴더 다시 선택」을 누르세요.',
      errorCode: 'no_folder',
      fileName: fileName,
    );
  }

  try {
    if (!await _requestPermission(handle)) {
      return TransferWriteResult.failed(
        message:
            'Inbox 쓰기 권한이 없습니다.\n'
            '다음 행동: 「전달 폴더 다시 선택」으로 권한을 다시 승인하세요.',
        errorCode: 'permission_denied',
        fileName: fileName,
      );
    }

    final id = (instructionId ?? '').trim().isNotEmpty
        ? instructionId!.trim()
        : _idFromJson(jsonText);
    final ver = (version != null && version > 0)
        ? version
        : _versionFromJson(jsonText);
    final checksum = (expectedChecksum ?? '').trim().isNotEmpty
        ? expectedChecksum!.trim()
        : stableContentChecksum(jsonText);

    return performInboxDirectTransfer(
      fileName: fileName,
      jsonText: jsonText,
      instructionId: id,
      version: ver,
      expectedChecksum: checksum,
      folderLabel: _folderName ?? 'Inbox',
      readExisting: (name) => _readExistingFile(handle, name),
      writeFile: (name, content) => _writeUtf8File(handle, name, content),
    );
  } catch (e) {
    return TransferWriteResult.failed(
      message:
          '직접 전달 실패: $e\n'
          '다운로드로 대체하지 않았습니다.\n'
          '다음 행동: 「전달 폴더 다시 선택」 또는 「수동 가져오기용 JSON 다운로드」를 사용하세요.',
      errorCode: 'write_failed',
      fileName: fileName,
    );
  }
}

/// 수동 가져오기용 JSON 다운로드 전용 (전달됨으로 표시하지 않음).
Future<TransferWriteResult> downloadJsonFile({
  required String fileName,
  required String jsonText,
}) async {
  _triggerManualDownload(fileName, jsonText);
  final checksum = stableContentChecksum(jsonText);
  return TransferWriteResult.downloadOnly(
    fileName: fileName,
    checksum: checksum,
    message: 'JSON 다운로드 완료 · 수동 가져오기 대기',
  );
}

Future<String?> readBackFile(String fileName) async {
  final handle = _directoryHandle;
  if (handle == null) return null;
  final result = await _readExistingFile(handle, fileName);
  return result.text;
}

String _idFromJson(String jsonText) {
  try {
    final map = jsonDecode(jsonText);
    if (map is Map) return '${map['instructionId'] ?? ''}'.trim();
  } catch (_) {}
  return '';
}

int _versionFromJson(String jsonText) {
  try {
    final map = jsonDecode(jsonText);
    if (map is Map) {
      return int.tryParse(
            '${map['instructionVersion'] ?? map['version'] ?? ''}'.trim(),
          ) ??
          0;
    }
  } catch (_) {}
  return 0;
}
