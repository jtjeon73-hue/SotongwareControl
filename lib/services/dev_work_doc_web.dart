import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'dev_work_doc_fs.dart';
import 'dev_work_doc_paths.dart';
import 'dev_work_doc_save_pipeline.dart';
import 'dev_work_doc_types.dart';
import 'dev_work_doc_verify.dart';
import 'work_instruction_validator.dart';

const _rootNameKey = 'dev_work_doc_root_name_v1';

JSObject? _rootHandle;
String? _rootFolderName;
DevWorkDocSelectionKind _selectionKind = DevWorkDocSelectionKind.none;
bool _structureOk = false;
bool _writeProbeOk = false;

/// 진단 로그 (절대경로·JSON 본문 금지).
void _diag(String step, [String detail = '']) {
  final line = detail.isEmpty ? step : '$step: $detail';
  if (kDebugMode) {
    debugPrint('[DevWorkDoc] $line');
  }
}

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

/// callMethod에 List.toJS를 한 덩어리로 넘기면 브라우저가 단일 인자로 받아
/// create 옵션이 무시되고, name이 "foo,[object Object]"로 깨진다.
/// 인자는 반드시 개별 전달한다.
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

String _domName(Object e) {
  final s = '$e';
  if (s.contains('NotFoundError')) return 'NotFoundError';
  if (s.contains('NotAllowedError')) return 'NotAllowedError';
  if (s.contains('TypeMismatchError')) return 'TypeMismatchError';
  if (s.contains('InvalidStateError')) return 'InvalidStateError';
  return e.runtimeType.toString();
}

bool _isNotFound(Object e) {
  final n = _domName(e);
  return n == 'NotFoundError' || '$e'.contains('NotFoundError');
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

Future<DevWorkDocState> _buildState({String? statusMessage}) async {
  final prefs = await SharedPreferences.getInstance();
  _rootFolderName ??= prefs.getString(_rootNameKey);
  final supported = _isSupported();
  final handle = _rootHandle;
  var granted = false;
  if (handle != null) {
    granted = await _hasPermission(handle);
  }
  final ready =
      supported &&
      handle != null &&
      granted &&
      _selectionKind == DevWorkDocSelectionKind.devWorkDocRoot &&
      _structureOk &&
      _writeProbeOk;
  return DevWorkDocState(
    supported: supported,
    hasRoot: handle != null,
    rootFolderName: _rootFolderName,
    permissionGranted: granted,
    selectionKind: handle == null
        ? DevWorkDocSelectionKind.none
        : _selectionKind,
    structureOk: _structureOk,
    readyToWrite: ready,
    statusMessage:
        statusMessage ??
        (ready
            ? '선택 기준: DevWorkDoc 루트 · 쓰기 권한: 허용 · 저장 준비: 완료'
            : handle == null
            ? 'DevWorkDoc 폴더를 선택해 주세요.'
            : !granted
            ? '쓰기 권한 재승인이 필요합니다.'
            : !_structureOk
            ? '경로 구조 준비가 필요합니다.'
            : !_writeProbeOk
            ? '쓰기 프로브가 실패했습니다. 폴더를 다시 선택하세요.'
            : '선택 기준을 확인해 주세요.'),
  );
}

Future<DevWorkDocState> currentState() => _buildState();

Future<List<String>> _listChildNames(JSObject dir) async {
  return _listEntryNames(dir);
}

Future<DevWorkDocState> pickRootFolder() async {
  if (!_isSupported()) {
    return const DevWorkDocState(
      supported: false,
      hasRoot: false,
      statusMessage: '이 브라우저는 폴더 접근을 지원하지 않습니다.',
    );
  }
  try {
    final handle =
        await (web.window.callMethod(
                  'showDirectoryPicker'.toJS,
                  _jsOpts({'mode': 'readwrite', 'id': 'dev-work-doc-root'}),
                )
                as JSPromise<JSObject>)
            .toDart;

    final granted = await _requestPermission(handle);
    if (!granted) {
      _rootHandle = null;
      _structureOk = false;
      _writeProbeOk = false;
      return const DevWorkDocState(
        supported: true,
        hasRoot: false,
        permissionGranted: false,
        selectionKind: DevWorkDocSelectionKind.none,
        statusMessage: '쓰기 권한이 거부되었습니다. 다시 선택해 주세요.',
      );
    }

    final nameProp = handle.getProperty('name'.toJS);
    final name = nameProp == null
        ? 'DevWorkDoc'
        : (nameProp as JSString).toDart;
    final children = await _listChildNames(handle);
    final kind = classifySelection(folderName: name, childNames: children);

    _rootHandle = handle;
    _rootFolderName = name;
    _selectionKind = kind;
    _structureOk = false;
    _writeProbeOk = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rootNameKey, name);

    if (kind == DevWorkDocSelectionKind.repoRootWithDevWorkDoc) {
      return _buildState(
        statusMessage:
            '저장소 루트로 보입니다. 하위 「DevWorkDoc」을 사용하려면 「DevWorkDoc 하위 폴더 사용」을 누르거나, '
            'DevWorkDoc 폴더를 다시 선택하세요.',
      );
    }

    if (kind == DevWorkDocSelectionKind.ambiguous) {
      final structure = await ensureStructure();
      if (structure.ok) {
        final refreshedChildren = await _listChildNames(handle);
        final kind2 = classifySelection(
          folderName: name,
          childNames: refreshedChildren,
        );
        if (kind2 == DevWorkDocSelectionKind.devWorkDocRoot ||
            name.toLowerCase() == 'devworkdoc') {
          _selectionKind = DevWorkDocSelectionKind.devWorkDocRoot;
          await _runWriteProbe();
          return _buildState(
            statusMessage:
                '선택 기준: DevWorkDoc 루트 · 쓰기 권한: 허용 · 경로 구조: 정상 · 저장 준비: '
                '${_writeProbeOk ? '완료' : '프로브 실패'}',
          );
        }
      }
      return _buildState(
        statusMessage:
            '선택 폴더「$name」가 DevWorkDoc 루트인지 확인이 필요합니다. '
            '폴더 이름이 DevWorkDoc 인 폴더를 선택하는 것을 권장합니다.',
      );
    }

    final structure = await ensureStructure();
    if (structure.ok) {
      _selectionKind = DevWorkDocSelectionKind.devWorkDocRoot;
      await _runWriteProbe();
    }
    return _buildState(
      statusMessage: structure.ok
          ? '선택 기준: DevWorkDoc 루트 · 쓰기 권한: 허용 · 경로 구조: 정상 · 저장 준비: '
                '${_writeProbeOk ? '완료' : '프로브 실패'}'
          : structure.message,
    );
  } catch (_) {
    _structureOk = false;
    _writeProbeOk = false;
    return _buildState(statusMessage: '폴더 선택이 취소되었거나 실패했습니다.');
  }
}

/// 저장소 루트 선택 시 하위 DevWorkDoc 핸들로 전환.
Future<DevWorkDocState> useNestedDevWorkDocFolder() async {
  final root = _rootHandle;
  if (root == null) {
    return _buildState(statusMessage: '먼저 폴더를 선택하세요.');
  }
  if (!await _requestPermission(root)) {
    return _buildState(statusMessage: '쓰기 권한 재승인이 필요합니다.');
  }
  try {
    final nested =
        await _call1(root, 'getDirectoryHandle', 'DevWorkDoc'.toJS) as JSObject;
    if (!await _requestPermission(nested)) {
      return _buildState(statusMessage: 'DevWorkDoc 하위 폴더 권한이 필요합니다.');
    }
    _rootHandle = nested;
    _rootFolderName = 'DevWorkDoc';
    _selectionKind = DevWorkDocSelectionKind.devWorkDocRoot;
    _structureOk = false;
    _writeProbeOk = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rootNameKey, 'DevWorkDoc');
    final structure = await ensureStructure();
    if (structure.ok) await _runWriteProbe();
    return _buildState(
      statusMessage: structure.ok
          ? '선택 기준: DevWorkDoc 루트(하위) · 쓰기 권한: 허용 · 저장 준비: '
                '${_writeProbeOk ? '완료' : '프로브 실패'}'
          : structure.message,
    );
  } catch (e) {
    return _buildState(statusMessage: '하위에서 DevWorkDoc을 찾지 못했습니다. ($e)');
  }
}

Future<JSObject?> _requireRoot() async {
  final handle = _rootHandle;
  if (handle == null) return null;
  if (!await _requestPermission(handle)) return null;
  return handle;
}

Future<JSObject> _getOrCreateDir(JSObject parent, String name) async {
  _diag('getDirectoryHandle', '$name create=true');
  final result = await _call2(
    parent,
    'getDirectoryHandle',
    name.toJS,
    _jsOpts({'create': true}),
  );
  return result as JSObject;
}

Future<JSObject?> _getExistingDir(JSObject parent, String name) async {
  try {
    _diag('getDirectoryHandle', '$name create=false');
    final result = await _call1(parent, 'getDirectoryHandle', name.toJS);
    return result as JSObject;
  } catch (e) {
    if (_isNotFound(e)) return null;
    rethrow;
  }
}

Future<JSObject> _resolveDirCreate(JSObject root, List<String> segments) async {
  var dir = root;
  for (final part in segments) {
    if (part.isEmpty) {
      throw DevWorkDocStepError(
        step: DevWorkDocSaveStep.artifactDir,
        relativePath: segments.join('/'),
        domName: 'InvalidStateError',
        message: '빈 경로 세그먼트',
      );
    }
    dir = await _getOrCreateDir(dir, part);
  }
  return dir;
}

Future<JSObject?> _resolveDirExisting(
  JSObject root,
  List<String> segments,
) async {
  var dir = root;
  for (final part in segments) {
    final next = await _getExistingDir(dir, part);
    if (next == null) return null;
    dir = next;
  }
  return dir;
}

Future<void> _writeTextFileAt(
  JSObject dir,
  String fileName,
  String content, {
  required String stepCreate,
  required String stepWrite,
  required String relativePath,
}) async {
  try {
    _diag(stepCreate, relativePath);
    final fileHandle =
        await _call2(
              dir,
              'getFileHandle',
              fileName.toJS,
              _jsOpts({'create': true}),
            )
            as JSObject;

    _diag(stepWrite, '${content.length} chars');
    final writable = await _call0(fileHandle, 'createWritable') as JSObject;

    final bytes = Uint8List.fromList(utf8.encode(content));
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
    );
    await _call1(writable, 'write', blob);
    await _call0(writable, 'close');
  } catch (e) {
    throw DevWorkDocStepError(
      step: stepWrite,
      relativePath: relativePath,
      domName: _domName(e),
      message: '파일 쓰기 실패. 다음 행동: 코드/권한 확인 후 관리자에게 보고',
    );
  }
}

Future<({String? text, int size})> _readTextFileAt(
  JSObject root,
  List<String> dirSegments,
  String fileName,
) async {
  try {
    final dir = dirSegments.isEmpty
        ? root
        : await _resolveDirExisting(root, dirSegments);
    if (dir == null) return (text: null, size: 0);

    final fileHandle =
        await _call1(dir, 'getFileHandle', fileName.toJS) as JSObject;
    final file = await _call0(fileHandle, 'getFile') as JSObject;
    final sizeProp = file.getProperty('size'.toJS);
    final size = sizeProp == null ? 0 : (sizeProp as JSNumber).toDartInt;
    if (size <= 0) return (text: '', size: 0);

    final textJs = await _call0(file, 'text');
    if (textJs == null) return (text: null, size: size);
    return (text: (textJs as JSString).toDart, size: size);
  } catch (e) {
    if (_isNotFound(e)) return (text: null, size: 0);
    return (text: null, size: 0);
  }
}

Future<void> _writeTextFile(
  JSObject root,
  String relativePath,
  String content,
) async {
  final segments = relativePath.split('/').where((p) => p.isNotEmpty).toList();
  final fileName = segments.removeLast();
  final dir = segments.isEmpty ? root : await _resolveDirCreate(root, segments);
  await _writeTextFileAt(
    dir,
    fileName,
    content,
    stepCreate: DevWorkDocSaveStep.activeFileCreate,
    stepWrite: DevWorkDocSaveStep.activeFileWrite,
    relativePath: relativePath,
  );
}

Future<({String? text, int size})> _readTextFileExisting(
  JSObject root,
  String relativePath,
) async {
  final segments = relativePath.split('/').where((p) => p.isNotEmpty).toList();
  final fileName = segments.removeLast();
  return _readTextFileAt(root, segments, fileName);
}

Future<void> _deleteFile(JSObject root, String relativePath) async {
  final segments = relativePath.split('/').where((p) => p.isNotEmpty).toList();
  final fileName = segments.removeLast();
  final dir = segments.isEmpty
      ? root
      : await _resolveDirExisting(root, segments);
  if (dir == null) return;
  try {
    await _call1(dir, 'removeEntry', fileName.toJS);
  } catch (_) {}
}

Future<void> _deleteDirRecursive(JSObject root, String relativeDir) async {
  try {
    final segments = relativeDir.split('/').where((p) => p.isNotEmpty).toList();
    final dirName = segments.removeLast();
    final parent = segments.isEmpty
        ? root
        : await _resolveDirExisting(root, segments);
    if (parent == null) return;
    await _call2(
      parent,
      'removeEntry',
      dirName.toJS,
      _jsOpts({'recursive': true}),
    );
  } catch (_) {}
}

Future<List<String>> _listEntryNames(JSObject dirHandle) async {
  final names = <String>[];
  try {
    final valuesMethod = dirHandle.getProperty('values'.toJS);
    if (valuesMethod == null) return names;
    final values =
        (valuesMethod as JSFunction).callAsFunction(dirHandle) as JSObject;
    while (true) {
      final result = await _call0(values, 'next') as JSObject;
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

/// 정적 폴더 create·임시 파일 쓰기/삭제 프로브 (흔적 남기지 않음).
Future<void> _runWriteProbe() async {
  _writeProbeOk = false;
  final root = _rootHandle;
  if (root == null) return;
  try {
    _diag(DevWorkDocSaveStep.root, 'probe');
    final ebook = await _getOrCreateDir(root, 'Ebook');
    final active = await _getOrCreateDir(ebook, 'Active');
    await _getOrCreateDir(ebook, 'Versions');

    const probeName = '.devworkdoc_write_probe.tmp';
    await _writeTextFileAt(
      active,
      probeName,
      'ok',
      stepCreate: 'write_probe_create',
      stepWrite: 'write_probe_write',
      relativePath: 'Ebook/Active/$probeName',
    );
    final read = await _readTextFileAt(root, ['Ebook', 'Active'], probeName);
    await _call1(active, 'removeEntry', probeName.toJS);
    if (read.text != 'ok') {
      _diag('write_probe', 'reread mismatch');
      return;
    }
    _writeProbeOk = true;
    _diag('write_probe', 'ok');
  } catch (e) {
    _diag('write_probe', 'failed ${_domName(e)}');
    _writeProbeOk = false;
  }
}

/// 브라우저 FSA → DevWorkDocFsAdapter
class _WebDevWorkDocFs implements DevWorkDocFsAdapter {
  _WebDevWorkDocFs(this.root);

  final JSObject root;

  @override
  Future<bool> dirExists(List<String> segments) async {
    final d = await _resolveDirExisting(root, segments);
    return d != null;
  }

  @override
  Future<void> ensureDir(List<String> segments, {required bool create}) async {
    if (segments.isEmpty) return;
    if (create) {
      try {
        await _resolveDirCreate(root, segments);
      } catch (e) {
        throw FsNotFoundException(
          step: DevWorkDocSaveStep.instructionDir,
          relativePath: segments.join('/'),
          message: '${_domName(e)}: ${segments.join('/')}',
        );
      }
    } else {
      final d = await _resolveDirExisting(root, segments);
      if (d == null) {
        throw FsNotFoundException(
          step: 'getDirectoryHandle',
          relativePath: segments.join('/'),
          message: 'Directory not found (create:false)',
        );
      }
    }
  }

  @override
  Future<bool> fileExists(List<String> dirSegments, String fileName) async {
    final r = await readFile(dirSegments, fileName);
    return r.text != null;
  }

  @override
  Future<void> writeFile(
    List<String> dirSegments,
    String fileName,
    String content,
  ) async {
    final rel = [...dirSegments, fileName].join('/');
    try {
      final dir = await _resolveDirCreate(root, dirSegments);
      await _writeTextFileAt(
        dir,
        fileName,
        content,
        stepCreate: DevWorkDocSaveStep.versionFileCreate,
        stepWrite: DevWorkDocSaveStep.versionFileWrite,
        relativePath: rel,
      );
    } on DevWorkDocStepError {
      rethrow;
    } catch (e) {
      throw FsNotFoundException(
        step: DevWorkDocSaveStep.versionFileWrite,
        relativePath: rel,
        message: _domName(e),
      );
    }
  }

  @override
  Future<({String? text, int size})> readFile(
    List<String> dirSegments,
    String fileName,
  ) => _readTextFileAt(root, dirSegments, fileName);
}

Future<DevWorkDocWriteResult> ensureStructure() async {
  if (!_isSupported()) {
    return DevWorkDocWriteResult.failed(
      message: '이 브라우저는 DevWorkDoc 폴더 접근을 지원하지 않습니다.',
      errorCode: 'unsupported',
    );
  }
  final root = await _requireRoot();
  if (root == null) {
    _structureOk = false;
    return DevWorkDocWriteResult.failed(
      message: 'DevWorkDoc 루트 폴더를 선택해 주세요.',
      errorCode: 'no_root',
      outcome: DevWorkDocSaveOutcome.permissionNeeded,
    );
  }
  try {
    for (final artifact in DevWorkDocPaths.allArtifacts) {
      final art = await _getOrCreateDir(root, artifact);
      for (final sub in DevWorkDocPaths.subFolders) {
        await _getOrCreateDir(art, sub);
      }
    }
    _structureOk = true;
    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      outcome: DevWorkDocSaveOutcome.completeSuccess,
      message: 'DevWorkDoc「${_rootFolderName ?? ''}」폴더 구조를 준비했습니다.',
    );
  } catch (e) {
    _structureOk = false;
    return DevWorkDocWriteResult.failed(
      message:
          '실패 단계: structure_ensure\n대상: App|Ebook|…/Active|Versions|Archive\n'
          '오류: ${_domName(e)}\n폴더 구조 생성에 실패했습니다.',
      errorCode: 'structure_failed',
    );
  }
}

Future<DevWorkDocWriteResult> downloadInstructionJson({
  required String artifactType,
  required String instructionId,
  required int version,
  required String jsonText,
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
  _triggerDownload(fileName, jsonText);
  return DevWorkDocWriteResult.download(
    fileName: fileName,
    activePathHint: activePath,
    versionPathHint: versionPath,
    message:
        '브라우저 다운로드 완료 (DevWorkDoc 직접 저장 아님). '
        '폴더 저장 성공으로 계산하지 않습니다.',
  );
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

  if (!_isSupported()) {
    return DevWorkDocWriteResult.failed(
      message: '이 브라우저는 폴더 직접 저장을 지원하지 않습니다. 「수동 가져오기용 JSON 다운로드」를 사용하세요.',
      errorCode: 'unsupported',
      activePathHint: activePath,
      versionPathHint: versionPath,
    );
  }

  final root = await _requireRoot();
  if (root == null) {
    return DevWorkDocWriteResult.failed(
      message:
          '실패 단계: root_handle\n대상: DevWorkDoc\n오류: NotAllowedError\n'
          '루트가 없거나 권한이 없습니다. 폴더를 다시 선택하세요.',
      errorCode: 'no_root',
      outcome: DevWorkDocSaveOutcome.permissionNeeded,
      activePathHint: activePath,
      versionPathHint: versionPath,
    );
  }

  if (_selectionKind != DevWorkDocSelectionKind.devWorkDocRoot) {
    return DevWorkDocWriteResult.failed(
      message:
          '실패 단계: root_handle\n대상: (선택 폴더)\n오류: InvalidStateError\n'
          'DevWorkDoc 루트로 확정되지 않았습니다. 폴더를 다시 선택하세요.',
      errorCode: 'bad_root',
      activePathHint: activePath,
      versionPathHint: versionPath,
    );
  }

  _diag(DevWorkDocSaveStep.root, 'save start');
  final pipeline = DevWorkDocSavePipeline(_WebDevWorkDocFs(root));
  final result = await pipeline.saveInstruction(
    artifactType: artifactType,
    instructionId: instructionId,
    version: version,
    jsonText: jsonText,
    isNewVersion: isNewVersion,
  );
  if (!result.ok && kDebugMode) {
    for (final line in pipeline.diagnostics) {
      debugPrint('[DevWorkDoc] $line');
    }
  }
  return result;
}

Future<String?> readActive(String artifactType, String instructionId) async {
  final root = _rootHandle;
  if (root == null) return null;
  if (!await _hasPermission(root)) return null;
  final path = DevWorkDocPaths.activeRelative(artifactType, instructionId);
  final result = await _readTextFileExisting(root, path);
  return result.text;
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

  final root = await _requireRoot();
  if (root == null) {
    return DevWorkDocWriteResult.failed(
      message: 'DevWorkDoc 루트 폴더를 선택해 주세요.',
      errorCode: 'no_root',
      outcome: DevWorkDocSaveOutcome.permissionNeeded,
    );
  }

  try {
    final content = await _readTextFileExisting(root, activePath);
    if (content.text == null || content.size <= 0) {
      return DevWorkDocWriteResult.failed(
        message:
            '실패 단계: active_read\n대상: $activePath\n오류: NotFoundError\nActive 파일이 없습니다.',
        errorCode: 'not_found',
        activePathHint: activePath,
      );
    }

    await _writeTextFile(root, archivePath, content.text!);
    final archiveRead = await _readTextFileExisting(root, archivePath);
    if (archiveRead.size <= 0 || archiveRead.text == null) {
      return DevWorkDocWriteResult.failed(
        message:
            '실패 단계: archive_reread\n대상: $archivePath\n오류: NotFoundError\nArchive 쓰기 검증 실패',
        errorCode: 'verify_failed',
      );
    }
    await _deleteFile(root, activePath);

    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      outcome: DevWorkDocSaveOutcome.completeSuccess,
      activePathHint: activePath,
      versionPathHint: archivePath,
      checksum: contentChecksum(content.text!),
      message: 'Active → Archive 보관 완료 (Versions 유지)',
      activeVerified: true,
      versionsVerified: true,
      activeBytes: archiveRead.size,
    );
  } on DevWorkDocStepError catch (e) {
    return DevWorkDocWriteResult.failed(
      message: e.userMessage,
      errorCode: 'archive_failed',
    );
  } catch (e) {
    return DevWorkDocWriteResult.failed(
      message: '보관 실패: ${_domName(e)}',
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

  final root = await _requireRoot();
  if (root == null) {
    return DevWorkDocWriteResult.failed(
      message: 'DevWorkDoc 루트 폴더를 선택해 주세요.',
      errorCode: 'no_root',
      outcome: DevWorkDocSaveOutcome.permissionNeeded,
    );
  }

  try {
    final archiveDir = await _resolveDirExisting(root, [folder, 'Archive']);
    if (archiveDir == null) {
      return DevWorkDocWriteResult.failed(
        message:
            '실패 단계: archive_directory\n대상: $folder/Archive\n오류: NotFoundError',
        errorCode: 'not_found',
      );
    }
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

    if (bestFileName == null) {
      return DevWorkDocWriteResult.failed(
        message: 'Archive에 복원할 버전이 없습니다.',
        errorCode: 'not_found',
      );
    }

    final archivePath = '$folder/Archive/$bestFileName';
    final content = await _readTextFileExisting(root, archivePath);
    if (content.text == null || content.size <= 0) {
      return DevWorkDocWriteResult.failed(
        message: 'Archive 파일을 읽을 수 없습니다.',
        errorCode: 'read_failed',
      );
    }

    await _writeTextFile(root, activePath, content.text!);
    final activeRead = await _readTextFileExisting(root, activePath);
    if (activeRead.size <= 0) {
      return DevWorkDocWriteResult.failed(
        message:
            '실패 단계: active_file_reread\n대상: $activePath\n오류: NotFoundError\n복원 후 Active 검증 실패',
        errorCode: 'verify_failed',
      );
    }

    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      outcome: DevWorkDocSaveOutcome.completeSuccess,
      activePathHint: activePath,
      versionPathHint: archivePath,
      checksum: contentChecksum(content.text!),
      message: 'Archive v$bestVersion → Active 복원·검증 완료',
      activeVerified: true,
      versionsVerified: true,
      activeBytes: activeRead.size,
    );
  } on DevWorkDocStepError catch (e) {
    return DevWorkDocWriteResult.failed(
      message: e.userMessage,
      errorCode: 'restore_failed',
    );
  } catch (e) {
    return DevWorkDocWriteResult.failed(
      message: '복원 실패: ${_domName(e)}',
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

  final root = await _requireRoot();
  if (root == null) {
    return DevWorkDocWriteResult.failed(
      message: 'DevWorkDoc 루트 폴더를 선택해 주세요.',
      errorCode: 'no_root',
      outcome: DevWorkDocSaveOutcome.permissionNeeded,
    );
  }

  try {
    try {
      await _deleteFile(root, activePath);
    } catch (_) {}
    await _deleteDirRecursive(root, versionDir);

    final archiveDir = await _resolveDirExisting(root, [folder, 'Archive']);
    if (archiveDir != null) {
      final names = await _listEntryNames(archiveDir);
      for (final name in names) {
        if (name.startsWith(prefix)) {
          await _deleteFile(root, '$folder/Archive/$name');
        }
      }
    }

    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      outcome: DevWorkDocSaveOutcome.completeSuccess,
      activePathHint: activePath,
      message: 'Active·Versions·Archive 항목을 삭제했습니다.',
    );
  } catch (e) {
    return DevWorkDocWriteResult.failed(
      message: '삭제 실패: ${_domName(e)}',
      errorCode: 'delete_failed',
    );
  }
}
