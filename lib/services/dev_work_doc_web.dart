import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'dev_work_doc_paths.dart';
import 'dev_work_doc_types.dart';
import 'work_instruction_validator.dart';

const _rootNameKey = 'dev_work_doc_root_name_v1';

JSObject? _rootHandle;
String? _rootFolderName;

bool _isSupported() {
  try {
    return web.window.hasProperty('showDirectoryPicker'.toJS).toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> _hasPermission(JSObject handle) async {
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
    return '$status' == 'granted';
  } catch (_) {
    return false;
  }
}

Future<bool> _requestPermission(JSObject handle) async {
  try {
    final status =
        await (handle.callMethod(
                  'requestPermission'.toJS,
                  [
                    {'mode': 'readwrite'}.jsify(),
                  ].toJS,
                )
                as JSPromise)
            .toDart;
    return '$status' == 'granted';
  } catch (_) {
    return false;
  }
}

Future<DevWorkDocState> currentState() async {
  final prefs = await SharedPreferences.getInstance();
  _rootFolderName ??= prefs.getString(_rootNameKey);
  final supported = _isSupported();
  var granted = false;
  final handle = _rootHandle;
  if (handle != null) {
    granted = await _hasPermission(handle);
  }
  return DevWorkDocState(
    supported: supported,
    hasRoot: handle != null,
    rootFolderName: _rootFolderName,
    permissionGranted: granted,
  );
}

Future<DevWorkDocState> pickRootFolder() async {
  if (!_isSupported()) {
    return const DevWorkDocState(supported: false, hasRoot: false);
  }
  try {
    final handle =
        await (web.window.callMethod(
                  'showDirectoryPicker'.toJS,
                  [
                    {'mode': 'readwrite', 'id': 'dev-work-doc-root'}.jsify(),
                  ].toJS,
                )
                as JSPromise<JSObject>)
            .toDart;
    _rootHandle = handle;
    final nameProp = handle.getProperty('name'.toJS);
    _rootFolderName = nameProp == null
        ? 'DevWorkDoc'
        : (nameProp as JSString).toDart;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rootNameKey, _rootFolderName ?? 'DevWorkDoc');
    return DevWorkDocState(
      supported: true,
      hasRoot: true,
      rootFolderName: _rootFolderName,
      permissionGranted: true,
    );
  } catch (_) {
    return DevWorkDocState(
      supported: true,
      hasRoot: _rootHandle != null,
      rootFolderName: _rootFolderName,
      permissionGranted: false,
    );
  }
}

Future<JSObject?> _requireRoot() async {
  final handle = _rootHandle;
  if (handle == null) return null;
  if (!await _requestPermission(handle)) return null;
  return handle;
}

Future<JSObject> _getOrCreateDir(JSObject parent, String name) async {
  return await (parent.callMethod(
            'getDirectoryHandle'.toJS,
            [
              name.toJS,
              {'create': true}.jsify(),
            ].toJS,
          )
          as JSPromise<JSObject>)
      .toDart;
}

Future<JSObject> _resolveDir(JSObject root, String relativeDir) async {
  var dir = root;
  final parts = relativeDir.split('/').where((p) => p.isNotEmpty);
  for (final part in parts) {
    dir = await _getOrCreateDir(dir, part);
  }
  return dir;
}

Future<void> _writeTextFile(
  JSObject root,
  String relativePath,
  String content,
) async {
  final segments = relativePath.split('/');
  final fileName = segments.removeLast();
  final dir = segments.isEmpty
      ? root
      : await _resolveDir(root, segments.join('/'));
  final fileHandle =
      await (dir.callMethod(
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
  await (writable.callMethod('write'.toJS, [content.toJS].toJS) as JSPromise)
      .toDart;
  await (writable.callMethod('close'.toJS) as JSPromise).toDart;
}

Future<String?> _readTextFile(JSObject root, String relativePath) async {
  try {
    final segments = relativePath.split('/');
    final fileName = segments.removeLast();
    final dir = segments.isEmpty
        ? root
        : await _resolveDir(root, segments.join('/'));
    final fileHandle =
        await (dir.callMethod('getFileHandle'.toJS, [fileName.toJS].toJS)
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

Future<void> _deleteFile(JSObject root, String relativePath) async {
  final segments = relativePath.split('/');
  final fileName = segments.removeLast();
  final dir = segments.isEmpty
      ? root
      : await _resolveDir(root, segments.join('/'));
  await (dir.callMethod('removeEntry'.toJS, [fileName.toJS].toJS) as JSPromise)
      .toDart;
}

Future<void> _deleteDirRecursive(JSObject root, String relativeDir) async {
  try {
    final segments = relativeDir.split('/');
    final dirName = segments.removeLast();
    final parent = segments.isEmpty
        ? root
        : await _resolveDir(root, segments.join('/'));
    await (parent.callMethod(
              'removeEntry'.toJS,
              [
                dirName.toJS,
                {'recursive': true}.jsify(),
              ].toJS,
            )
            as JSPromise)
        .toDart;
  } catch (_) {
    // already absent
  }
}

Future<List<String>> _listEntryNames(JSObject dirHandle) async {
  final names = <String>[];
  try {
    final valuesMethod = dirHandle.getProperty('values'.toJS);
    if (valuesMethod == null) return names;
    final values =
        (valuesMethod as JSFunction).callAsFunction(dirHandle) as JSObject;
    while (true) {
      final result =
          await (values.callMethod('next'.toJS) as JSPromise<JSObject>).toDart;
      final done = result.getProperty('done'.toJS);
      if (done != null && (done as JSBoolean).toDart) break;
      final value = result.getProperty('value'.toJS);
      if (value == null) break;
      final handle = value as JSObject;
      final nameProp = handle.getProperty('name'.toJS);
      if (nameProp != null) {
        names.add((nameProp as JSString).toDart);
      }
    }
  } catch (_) {}
  return names;
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

DevWorkDocWriteResult _downloadFallback({
  required String fileName,
  required String jsonText,
  required String activePathHint,
  required String versionPathHint,
  required String message,
  required String errorCode,
}) {
  _triggerDownload(fileName, jsonText);
  return DevWorkDocWriteResult(
    ok: true,
    mode: 'download',
    fileName: fileName,
    activePathHint: activePathHint,
    versionPathHint: versionPathHint,
    message: message,
    errorCode: errorCode,
  );
}

Future<DevWorkDocWriteResult> ensureStructure() async {
  if (!_isSupported()) {
    return const DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      message: '이 브라우저는 DevWorkDoc 폴더 접근을 지원하지 않습니다.',
      errorCode: 'unsupported',
    );
  }
  final root = await _requireRoot();
  if (root == null) {
    return const DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      message: 'DevWorkDoc 루트 폴더를 선택해 주세요.',
      errorCode: 'no_root',
    );
  }
  try {
    for (final artifact in DevWorkDocPaths.allArtifacts) {
      for (final sub in DevWorkDocPaths.subFolders) {
        await _getOrCreateDir(await _getOrCreateDir(root, artifact), sub);
      }
    }
    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      message: 'DevWorkDoc「${_rootFolderName ?? ''}」폴더 구조를 준비했습니다.',
    );
  } catch (e) {
    return DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      message: '폴더 구조 생성에 실패했습니다. ($e)',
      errorCode: 'structure_failed',
    );
  }
}

Future<DevWorkDocWriteResult> saveInstruction({
  required String artifactType,
  required String instructionId,
  required int version,
  required String jsonText,
  bool isNewVersion = false,
}) async {
  final activePath = DevWorkDocPaths.activeRelative(
    artifactType,
    instructionId,
  );
  final versionPath = DevWorkDocPaths.versionRelative(
    artifactType,
    instructionId,
    version,
  );
  final fileName =
      '${DevWorkDocPaths.wiBaseName(instructionId)}_v$version.json';

  if (!_isSupported()) {
    return _downloadFallback(
      fileName: fileName,
      jsonText: jsonText,
      activePathHint: activePath,
      versionPathHint: versionPath,
      message: '이 브라우저는 폴더 직접 저장을 지원하지 않습니다. 다운로드가 시작되었습니다.',
      errorCode: 'unsupported',
    );
  }

  final root = await _requireRoot();
  if (root == null) {
    return _downloadFallback(
      fileName: fileName,
      jsonText: jsonText,
      activePathHint: activePath,
      versionPathHint: versionPath,
      message:
          'DevWorkDoc 루트가 선택되지 않아 다운로드로 대체했습니다. '
          '「DevWorkDoc 폴더 설정」에서 루트를 선택한 뒤 다시 저장하세요.',
      errorCode: 'no_root',
    );
  }

  try {
    await _writeTextFile(root, versionPath, jsonText);
    await _writeTextFile(root, activePath, jsonText);

    final readBack = await _readTextFile(root, activePath);
    if (readBack == null) {
      throw StateError('read-back failed');
    }
    jsonDecode(readBack);

    final checksum = contentChecksum(jsonText);
    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      activePathHint: activePath,
      versionPathHint: versionPath,
      checksum: checksum,
      fileName: fileName,
      message:
          'DevWorkDoc「${_rootFolderName ?? ''}」에 저장했습니다. '
          '(Active + Versions)',
    );
  } catch (e) {
    return _downloadFallback(
      fileName: fileName,
      jsonText: jsonText,
      activePathHint: activePath,
      versionPathHint: versionPath,
      message: '폴더 저장에 실패해 다운로드로 대체했습니다. ($e)',
      errorCode: 'write_failed',
    );
  }
}

Future<String?> readActive(String artifactType, String instructionId) async {
  final root = _rootHandle;
  if (root == null) return null;
  if (!await _hasPermission(root)) return null;
  final path = DevWorkDocPaths.activeRelative(artifactType, instructionId);
  return _readTextFile(root, path);
}

Future<DevWorkDocWriteResult> archiveInstruction({
  required String artifactType,
  required String instructionId,
  required int version,
}) async {
  final activePath = DevWorkDocPaths.activeRelative(
    artifactType,
    instructionId,
  );
  final archivePath = DevWorkDocPaths.archiveRelative(
    artifactType,
    instructionId,
    version,
  );

  if (!_isSupported()) {
    return const DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      message: '이 브라우저는 보관 작업을 지원하지 않습니다.',
      errorCode: 'unsupported',
    );
  }

  final root = await _requireRoot();
  if (root == null) {
    return const DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      message: 'DevWorkDoc 루트 폴더를 선택해 주세요.',
      errorCode: 'no_root',
    );
  }

  try {
    final content = await _readTextFile(root, activePath);
    if (content == null) {
      return DevWorkDocWriteResult(
        ok: false,
        mode: 'failed',
        activePathHint: activePath,
        message: 'Active 파일이 없습니다.',
        errorCode: 'not_found',
      );
    }

    await _writeTextFile(root, archivePath, content);
    await _deleteFile(root, activePath);

    jsonDecode(content);
    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      activePathHint: activePath,
      versionPathHint: archivePath,
      checksum: contentChecksum(content),
      message: 'Active → Archive 로 보관했습니다. Versions 는 유지됩니다.',
    );
  } catch (e) {
    return DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      activePathHint: activePath,
      versionPathHint: archivePath,
      message: '보관에 실패했습니다. ($e)',
      errorCode: 'archive_failed',
    );
  }
}

Future<DevWorkDocWriteResult> restoreInstruction({
  required String artifactType,
  required String instructionId,
}) async {
  final activePath = DevWorkDocPaths.activeRelative(
    artifactType,
    instructionId,
  );
  final folder = DevWorkDocPaths.artifactFolder(artifactType);
  final prefix = '${DevWorkDocPaths.wiBaseName(instructionId)}_v';

  if (!_isSupported()) {
    return const DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      message: '이 브라우저는 복원 작업을 지원하지 않습니다.',
      errorCode: 'unsupported',
    );
  }

  final root = await _requireRoot();
  if (root == null) {
    return const DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      message: 'DevWorkDoc 루트 폴더를 선택해 주세요.',
      errorCode: 'no_root',
    );
  }

  try {
    final archiveDir = await _resolveDir(root, '$folder/Archive');
    final names = await _listEntryNames(archiveDir);
    final versionPattern = RegExp(r'_v(\d+)\.json$');
    var bestVersion = -1;
    String? bestFileName;
    for (final name in names) {
      if (!name.startsWith(prefix)) continue;
      final match = versionPattern.firstMatch(name);
      if (match == null) continue;
      final v = int.tryParse(match.group(1)!);
      if (v != null && v > bestVersion) {
        bestVersion = v;
        bestFileName = name;
      }
    }

    if (bestFileName == null || bestVersion < 0) {
      return DevWorkDocWriteResult(
        ok: false,
        mode: 'failed',
        activePathHint: activePath,
        message: 'Archive 에 복원할 버전이 없습니다.',
        errorCode: 'not_found',
      );
    }

    final archivePath = '$folder/Archive/$bestFileName';
    final content = await _readTextFile(root, archivePath);
    if (content == null) {
      return DevWorkDocWriteResult(
        ok: false,
        mode: 'failed',
        versionPathHint: archivePath,
        message: 'Archive 파일을 읽을 수 없습니다.',
        errorCode: 'read_failed',
      );
    }

    await _writeTextFile(root, activePath, content);
    jsonDecode(content);

    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      activePathHint: activePath,
      versionPathHint: archivePath,
      checksum: contentChecksum(content),
      message: 'Archive 최신(v$bestVersion) → Active 로 복원했습니다.',
    );
  } catch (e) {
    return DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      activePathHint: activePath,
      message: '복원에 실패했습니다. ($e)',
      errorCode: 'restore_failed',
    );
  }
}

Future<DevWorkDocWriteResult> permanentDelete({
  required String artifactType,
  required String instructionId,
}) async {
  final activePath = DevWorkDocPaths.activeRelative(
    artifactType,
    instructionId,
  );
  final versionDir = DevWorkDocPaths.versionDirRelative(
    artifactType,
    instructionId,
  );
  final folder = DevWorkDocPaths.artifactFolder(artifactType);
  final prefix = '${DevWorkDocPaths.wiBaseName(instructionId)}_v';

  if (!_isSupported()) {
    return const DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      message: '이 브라우저는 삭제 작업을 지원하지 않습니다.',
      errorCode: 'unsupported',
    );
  }

  final root = await _requireRoot();
  if (root == null) {
    return const DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      message: 'DevWorkDoc 루트 폴더를 선택해 주세요.',
      errorCode: 'no_root',
    );
  }

  try {
    try {
      await _deleteFile(root, activePath);
    } catch (_) {}

    await _deleteDirRecursive(root, versionDir);

    final archiveDir = await _resolveDir(root, '$folder/Archive');
    final names = await _listEntryNames(archiveDir);
    for (final name in names) {
      if (name.startsWith(prefix)) {
        await _deleteFile(root, '$folder/Archive/$name');
      }
    }

    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      activePathHint: activePath,
      message: 'Active·Versions·Archive 항목을 삭제했습니다.',
    );
  } catch (e) {
    return DevWorkDocWriteResult(
      ok: false,
      mode: 'failed',
      activePathHint: activePath,
      message: '삭제에 실패했습니다. ($e)',
      errorCode: 'delete_failed',
    );
  }
}
