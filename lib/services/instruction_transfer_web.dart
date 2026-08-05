import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'browser_json_download_service.dart';
import 'instruction_content_checksum.dart';
import 'instruction_transfer_core.dart';
import 'instruction_transfer_types.dart';

const _folderNameKey = 'sotong24_transfer_folder_name_v1';

/// 빌드·운영 진단용 경로 식별자 (다운로드 경로와 구분).
const inboxTransferPathId = 'inbox_fsa_typed_v1';

web.FileSystemDirectoryHandle? _directoryHandle;
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

Future<JSAny?> _call1(JSObject target, String method, JSAny? a1) async {
  return (target.callMethod(method.toJS, a1) as JSPromise).toDart;
}

bool _isSupported() {
  try {
    return web.window.hasProperty('showDirectoryPicker'.toJS).toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> _hasPermission(web.FileSystemDirectoryHandle handle) async {
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

Future<bool> _requestPermission(web.FileSystemDirectoryHandle handle) async {
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
  ensureBrowserJsonDownloadRegistered();
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
  ensureBrowserJsonDownloadRegistered();
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
                as JSPromise<web.FileSystemDirectoryHandle>)
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
    _folderName = handle.name.isEmpty ? 'Inbox' : handle.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderNameKey, _folderName ?? 'Inbox');
    return buildInboxFolderState(
      supported: true,
      hasHandle: true,
      folderName: _folderName,
      permissionGranted: true,
    );
  } catch (_) {
    final existing = _directoryHandle;
    return buildInboxFolderState(
      supported: true,
      hasHandle: existing != null,
      folderName: _folderName,
      permissionGranted: existing != null
          ? await _hasPermission(existing)
          : false,
    );
  }
}

Future<({String? text, int size})> _readExistingFile(
  web.FileSystemDirectoryHandle dir,
  String fileName,
) async {
  try {
    final fileHandle = await dir.getFileHandle(fileName).toDart;
    final file = await fileHandle.getFile().toDart;
    final size = file.size;
    if (size <= 0) return (text: '', size: 0);
    final textJs = await file.text().toDart;
    return (text: textJs.toDart, size: size);
  } catch (_) {
    return (text: null, size: 0);
  }
}

/// typed FSA: getFileHandle(name, {create:true}) → createWritable → write(Blob) → close
Future<void> _writeUtf8File(
  web.FileSystemDirectoryHandle dir,
  String fileName,
  String jsonText,
) async {
  final fileHandle = await dir
      .getFileHandle(fileName, web.FileSystemGetFileOptions(create: true))
      .toDart;
  final writable = await fileHandle.createWritable().toDart;
  final bytes = Uint8List.fromList(utf8.encode(jsonText));
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  await writable.write(blob).toDart;
  await writable.close().toDart;
}

/// Inbox 직접 전달. 이 함수 안에는 다운로드 코드가 없다.
Future<TransferWriteResult> writeJsonFile({
  required String fileName,
  required String jsonText,
  String? instructionId,
  int? version,
  String? expectedChecksum,
}) async {
  ensureBrowserJsonDownloadRegistered();
  final downloadsBefore = browserJsonDownloadCallCount;

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

    final result = await performInboxDirectTransfer(
      fileName: fileName,
      jsonText: jsonText,
      instructionId: id,
      version: ver,
      expectedChecksum: checksum,
      folderLabel: _folderName ?? handle.name,
      readExisting: (name) => _readExistingFile(handle, name),
      writeFile: (name, content) => _writeUtf8File(handle, name, content),
    );

    if (browserJsonDownloadCallCount != downloadsBefore) {
      return TransferWriteResult.failed(
        message:
            '직접 전달 경로에서 브라우저 다운로드가 감지되어 중단했습니다 '
            '(before=$downloadsBefore after=$browserJsonDownloadCallCount).\n'
            '경로: $inboxTransferPathId',
        errorCode: 'download_guard',
        fileName: fileName,
      );
    }

    return TransferWriteResult(
      ok: result.ok,
      mode: result.mode,
      outcome: result.outcome,
      fileName: result.fileName,
      message: result.message == null
          ? null
          : '${result.message}\n경로: $inboxTransferPathId · 폴더: ${_folderName ?? handle.name}',
      errorCode: result.errorCode,
      checksum: result.checksum,
      instructionId: result.instructionId,
      version: result.version,
      verified: result.verified,
      bytes: result.bytes,
      conflictDiffSummary: result.conflictDiffSummary,
      pathId: inboxTransferPathId,
      folderName: _folderName ?? handle.name,
      downloadCallsDuringTransfer:
          browserJsonDownloadCallCount - downloadsBefore,
    );
  } catch (e) {
    if (browserJsonDownloadCallCount != downloadsBefore) {
      return TransferWriteResult.failed(
        message:
            '직접 전달 실패 중 다운로드가 감지되어 차단했습니다. ($e)\n'
            '경로: $inboxTransferPathId',
        errorCode: 'download_guard',
        fileName: fileName,
      );
    }
    return TransferWriteResult.failed(
      message:
          '직접 전달 실패: $e\n'
          '다운로드로 대체하지 않았습니다.\n'
          '경로: $inboxTransferPathId\n'
          '다음 행동: 「전달 폴더 다시 선택」 또는 「수동 가져오기용 JSON 다운로드」를 사용하세요.',
      errorCode: 'write_failed',
      fileName: fileName,
    );
  }
}

/// 수동 가져오기용 JSON 다운로드 전용.
Future<TransferWriteResult> downloadJsonFile({
  required String fileName,
  required String jsonText,
}) async {
  ensureBrowserJsonDownloadRegistered();
  triggerBrowserJsonDownload(fileName: fileName, jsonText: jsonText);
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
