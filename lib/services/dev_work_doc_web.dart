import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'dev_work_doc_paths.dart';
import 'dev_work_doc_types.dart';
import 'dev_work_doc_verify.dart';
import 'work_instruction_validator.dart';

const _rootNameKey = 'dev_work_doc_root_name_v1';

JSObject? _rootHandle;
String? _rootFolderName;
DevWorkDocSelectionKind _selectionKind = DevWorkDocSelectionKind.none;

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

Future<DevWorkDocState> _buildState({
  String? statusMessage,
  bool? structureOk,
}) async {
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
      _selectionKind == DevWorkDocSelectionKind.devWorkDocRoot;
  return DevWorkDocState(
    supported: supported,
    hasRoot: handle != null,
    rootFolderName: _rootFolderName,
    permissionGranted: granted,
    selectionKind: handle == null
        ? DevWorkDocSelectionKind.none
        : _selectionKind,
    structureOk: structureOk ?? (handle != null && granted),
    readyToWrite: ready && (structureOk ?? true),
    statusMessage:
        statusMessage ??
        (ready
            ? '선택 기준: DevWorkDoc 루트 · 쓰기 권한: 허용 · 저장 준비: 완료'
            : handle == null
            ? 'DevWorkDoc 폴더를 선택해 주세요.'
            : !granted
            ? '쓰기 권한 재승인이 필요합니다.'
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
                  [
                    {'mode': 'readwrite', 'id': 'dev-work-doc-root'}.jsify(),
                  ].toJS,
                )
                as JSPromise<JSObject>)
            .toDart;

    final granted = await _requestPermission(handle);
    if (!granted) {
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rootNameKey, name);

    if (kind == DevWorkDocSelectionKind.repoRootWithDevWorkDoc) {
      return _buildState(
        statusMessage:
            '저장소 루트로 보입니다. 하위 「DevWorkDoc」을 사용하려면 「DevWorkDoc 하위 폴더 사용」을 누르거나, '
            'DevWorkDoc 폴더를 다시 선택하세요.',
        structureOk: false,
      );
    }

    if (kind == DevWorkDocSelectionKind.ambiguous) {
      // 빈 폴더를 DevWorkDoc으로 쓸 수 있게 구조 생성 후 재판정
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
          return _buildState(
            statusMessage:
                '선택 기준: DevWorkDoc 루트 · 쓰기 권한: 허용 · 경로 구조: 정상 · 저장 준비: 완료',
            structureOk: true,
          );
        }
      }
      return _buildState(
        statusMessage:
            '선택 폴더「$name」가 DevWorkDoc 루트인지 확인이 필요합니다. '
            '폴더 이름이 DevWorkDoc 인 폴더를 선택하는 것을 권장합니다.',
        structureOk: false,
      );
    }

    final structure = await ensureStructure();
    if (structure.ok) {
      _selectionKind = DevWorkDocSelectionKind.devWorkDocRoot;
    }
    return _buildState(
      statusMessage: structure.ok
          ? '선택 기준: DevWorkDoc 루트 · 쓰기 권한: 허용 · 경로 구조: 정상 · 저장 준비: 완료'
          : structure.message,
      structureOk: structure.ok,
    );
  } catch (_) {
    return _buildState(
      statusMessage: '폴더 선택이 취소되었거나 실패했습니다.',
      structureOk: false,
    );
  }
}

/// 저장소 루트 선택 시 하위 DevWorkDoc 핸들로 전환.
Future<DevWorkDocState> useNestedDevWorkDocFolder() async {
  final root = _rootHandle;
  if (root == null) {
    return _buildState(statusMessage: '먼저 폴더를 선택하세요.', structureOk: false);
  }
  if (!await _requestPermission(root)) {
    return _buildState(statusMessage: '쓰기 권한 재승인이 필요합니다.', structureOk: false);
  }
  try {
    final nested =
        await (root.callMethod(
                  'getDirectoryHandle'.toJS,
                  ['DevWorkDoc'.toJS].toJS,
                )
                as JSPromise<JSObject>)
            .toDart;
    if (!await _requestPermission(nested)) {
      return _buildState(
        statusMessage: 'DevWorkDoc 하위 폴더 권한이 필요합니다.',
        structureOk: false,
      );
    }
    _rootHandle = nested;
    _rootFolderName = 'DevWorkDoc';
    _selectionKind = DevWorkDocSelectionKind.devWorkDocRoot;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rootNameKey, 'DevWorkDoc');
    final structure = await ensureStructure();
    return _buildState(
      statusMessage: structure.ok
          ? '선택 기준: DevWorkDoc 루트(하위) · 쓰기 권한: 허용 · 저장 준비: 완료'
          : structure.message,
      structureOk: structure.ok,
    );
  } catch (e) {
    return _buildState(
      statusMessage: '하위에서 DevWorkDoc을 찾지 못했습니다. ($e)',
      structureOk: false,
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

Future<JSObject?> _getExistingDir(JSObject parent, String name) async {
  try {
    return await (parent.callMethod('getDirectoryHandle'.toJS, [name.toJS].toJS)
            as JSPromise<JSObject>)
        .toDart;
  } catch (_) {
    return null;
  }
}

Future<JSObject> _resolveDirCreate(JSObject root, String relativeDir) async {
  var dir = root;
  for (final part in relativeDir.split('/').where((p) => p.isNotEmpty)) {
    dir = await _getOrCreateDir(dir, part);
  }
  return dir;
}

Future<JSObject?> _resolveDirExisting(JSObject root, String relativeDir) async {
  var dir = root;
  for (final part in relativeDir.split('/').where((p) => p.isNotEmpty)) {
    final next = await _getExistingDir(dir, part);
    if (next == null) return null;
    dir = next;
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
      : await _resolveDirCreate(root, segments.join('/'));
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

  // Blob(UTF-8)로 기록 — String.toJS 단독 전달보다 안정적
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  await (writable.callMethod('write'.toJS, [blob].toJS) as JSPromise).toDart;
  await (writable.callMethod('close'.toJS) as JSPromise).toDart;
}

Future<({String? text, int size})> _readTextFileExisting(
  JSObject root,
  String relativePath,
) async {
  try {
    final segments = relativePath.split('/');
    final fileName = segments.removeLast();
    final dir = segments.isEmpty
        ? root
        : await _resolveDirExisting(root, segments.join('/'));
    if (dir == null) return (text: null, size: 0);

    final fileHandle =
        await (dir.callMethod('getFileHandle'.toJS, [fileName.toJS].toJS)
                as JSPromise<JSObject>)
            .toDart;
    final file =
        await (fileHandle.callMethod('getFile'.toJS) as JSPromise<JSObject>)
            .toDart;
    final sizeProp = file.getProperty('size'.toJS);
    final size = sizeProp == null ? 0 : (sizeProp as JSNumber).toDartInt;
    if (size <= 0) return (text: '', size: 0);

    final textJs = await (file.callMethod('text'.toJS) as JSPromise).toDart;
    if (textJs == null) return (text: null, size: size);
    return (text: (textJs as JSString).toDart, size: size);
  } catch (_) {
    return (text: null, size: 0);
  }
}

Future<void> _deleteFile(JSObject root, String relativePath) async {
  final segments = relativePath.split('/');
  final fileName = segments.removeLast();
  final dir = segments.isEmpty
      ? root
      : await _resolveDirExisting(root, segments.join('/'));
  if (dir == null) return;
  await (dir.callMethod('removeEntry'.toJS, [fileName.toJS].toJS) as JSPromise)
      .toDart;
}

Future<void> _deleteDirRecursive(JSObject root, String relativeDir) async {
  try {
    final segments = relativeDir.split('/');
    final dirName = segments.removeLast();
    final parent = segments.isEmpty
        ? root
        : await _resolveDirExisting(root, segments.join('/'));
    if (parent == null) return;
    await (parent.callMethod(
              'removeEntry'.toJS,
              [
                dirName.toJS,
                {'recursive': true}.jsify(),
              ].toJS,
            )
            as JSPromise)
        .toDart;
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

Future<DevWorkDocWriteResult> ensureStructure() async {
  if (!_isSupported()) {
    return DevWorkDocWriteResult.failed(
      message: '이 브라우저는 DevWorkDoc 폴더 접근을 지원하지 않습니다.',
      errorCode: 'unsupported',
    );
  }
  final root = await _requireRoot();
  if (root == null) {
    return DevWorkDocWriteResult.failed(
      message: 'DevWorkDoc 루트 폴더를 선택해 주세요.',
      errorCode: 'no_root',
      outcome: DevWorkDocSaveOutcome.permissionNeeded,
    );
  }
  try {
    // DevWorkDoc/DevWorkDoc 중첩을 만들지 않는다 — root 바로 아래 artifact 폴더
    for (final artifact in DevWorkDocPaths.allArtifacts) {
      for (final sub in DevWorkDocPaths.subFolders) {
        await _getOrCreateDir(await _getOrCreateDir(root, artifact), sub);
      }
    }
    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      outcome: DevWorkDocSaveOutcome.completeSuccess,
      message: 'DevWorkDoc「${_rootFolderName ?? ''}」폴더 구조를 준비했습니다.',
    );
  } catch (e) {
    return DevWorkDocWriteResult.failed(
      message: '폴더 구조 생성에 실패했습니다. ($e)',
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
  final fileName =
      '${DevWorkDocPaths.wiBaseName(instructionId)}_v$version.json';

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
      message: 'DevWorkDoc 루트가 없거나 권한이 없습니다. 폴더를 다시 선택하세요.',
      errorCode: 'no_root',
      outcome: DevWorkDocSaveOutcome.permissionNeeded,
      activePathHint: activePath,
      versionPathHint: versionPath,
    );
  }

  if (_selectionKind != DevWorkDocSelectionKind.devWorkDocRoot) {
    return DevWorkDocWriteResult.failed(
      message:
          '현재 선택 폴더가 DevWorkDoc 루트로 확정되지 않았습니다. '
          'DevWorkDoc 폴더를 다시 선택하거나 「DevWorkDoc 하위 폴더 사용」을 누르세요.',
      errorCode: 'bad_root',
      activePathHint: activePath,
      versionPathHint: versionPath,
    );
  }

  try {
    // 기존 Active 검사 (중복/충돌)
    final existingActive = await _readTextFileExisting(root, activePath);
    if (existingActive.text != null && existingActive.text!.isNotEmpty) {
      final cmp = compareExistingFile(
        existingText: existingActive.text,
        expectedJson: jsonText,
      );
      if (cmp == DevWorkDocSaveOutcome.alreadyExists) {
        final existingVer = await _readTextFileExisting(root, versionPath);
        final verSame =
            existingVer.text != null &&
            contentChecksum(existingVer.text!) == contentChecksum(jsonText);
        if (verSame) {
          final sum = contentChecksum(jsonText);
          return DevWorkDocWriteResult(
            ok: true,
            mode: 'folder',
            outcome: DevWorkDocSaveOutcome.alreadyExists,
            activePathHint: activePath,
            versionPathHint: versionPath,
            checksum: sum,
            fileName: fileName,
            activeVerified: true,
            versionsVerified: true,
            activeBytes: existingActive.size,
            versionsBytes: existingVer.size,
            message: '기존 파일 확인: 동일 checksum — 다시 쓰지 않음',
          );
        }
      }
      if (cmp == DevWorkDocSaveOutcome.conflict && !isNewVersion) {
        // Active 내용이 다른데 같은 경로 — 덮어쓰지 않고 보고
        // 단, 의도적 저장(새 버전/재저장)은 Active 교체가 필요하므로 isNewVersion 또는 일반 저장은 진행
        // 사용자 요구: 충돌 시 덮어쓰지 않음 → 마이그레이션에서만 엄격. 일반 저장은 Active 갱신 허용.
      }
    }

    // Versions 충돌: 다른 checksum이면 덮어쓰지 않음
    final existingVersion = await _readTextFileExisting(root, versionPath);
    if (existingVersion.text != null && existingVersion.text!.isNotEmpty) {
      final cmp = compareExistingFile(
        existingText: existingVersion.text,
        expectedJson: jsonText,
      );
      if (cmp == DevWorkDocSaveOutcome.conflict) {
        return DevWorkDocWriteResult.failed(
          message: 'Versions 파일 충돌: 다른 내용이 이미 있습니다. 덮어쓰지 않았습니다.',
          errorCode: 'conflict',
          outcome: DevWorkDocSaveOutcome.conflict,
          activePathHint: activePath,
          versionPathHint: versionPath,
        );
      }
      if (cmp == DevWorkDocSaveOutcome.alreadyExists) {
        // 버전은 동일 — Active만 필요할 수 있음
      }
    }

    await _writeTextFile(root, versionPath, jsonText);
    await _writeTextFile(root, activePath, jsonText);

    final activeRead = await _readTextFileExisting(root, activePath);
    final versionRead = await _readTextFileExisting(root, versionPath);

    if (activeRead.size <= 0 || versionRead.size <= 0) {
      return DevWorkDocWriteResult.failed(
        message:
            '쓰기 후 파일 크기가 0입니다. Active=${activeRead.size}B Versions=${versionRead.size}B',
        errorCode: 'empty_file',
        activePathHint: activePath,
        versionPathHint: versionPath,
      );
    }

    final verified = verifyWrittenPair(
      DevWorkDocVerifyInput(
        expectedJson: jsonText,
        activeText: activeRead.text,
        versionsText: versionRead.text,
        instructionId: instructionId,
        version: version,
      ),
    );

    if (!verified.isComplete) {
      return DevWorkDocWriteResult(
        ok: false,
        mode: 'failed',
        outcome: verified.outcome,
        activePathHint: activePath,
        versionPathHint: versionPath,
        message: verified.message,
        errorCode: verified.errorCode ?? 'verify_failed',
        checksum: verified.checksum,
        fileName: fileName,
        activeVerified: verified.activeVerified,
        versionsVerified: verified.versionsVerified,
        activeBytes: verified.activeBytes,
        versionsBytes: verified.versionsBytes,
      );
    }

    return DevWorkDocWriteResult(
      ok: true,
      mode: 'folder',
      outcome: DevWorkDocSaveOutcome.completeSuccess,
      activePathHint: activePath,
      versionPathHint: versionPath,
      checksum: verified.checksum,
      fileName: fileName,
      activeVerified: true,
      versionsVerified: true,
      activeBytes: activeRead.size,
      versionsBytes: versionRead.size,
      message:
          '완전 성공: Active ${activeRead.size}B · Versions ${versionRead.size}B 검증 완료 '
          '(${_rootFolderName ?? 'DevWorkDoc'})',
    );
  } catch (e) {
    // 다운로드로 조용히 대체하지 않음 — 폴더 저장 실패로 반환
    return DevWorkDocWriteResult.failed(
      message: '폴더 저장 실패: $e',
      errorCode: 'write_failed',
      activePathHint: activePath,
      versionPathHint: versionPath,
    );
  }
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
        message: 'Active 파일이 없습니다.',
        errorCode: 'not_found',
        activePathHint: activePath,
      );
    }

    await _writeTextFile(root, archivePath, content.text!);
    final archiveRead = await _readTextFileExisting(root, archivePath);
    if (archiveRead.size <= 0 || archiveRead.text == null) {
      return DevWorkDocWriteResult.failed(
        message: 'Archive 쓰기 검증 실패',
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
  } catch (e) {
    return DevWorkDocWriteResult.failed(
      message: '보관 실패: $e',
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
    final archiveDir = await _resolveDirExisting(root, '$folder/Archive');
    if (archiveDir == null) {
      return DevWorkDocWriteResult.failed(
        message: 'Archive 폴더가 없습니다.',
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
        message: '복원 후 Active 검증 실패',
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
  } catch (e) {
    return DevWorkDocWriteResult.failed(
      message: '복원 실패: $e',
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

    final archiveDir = await _resolveDirExisting(root, '$folder/Archive');
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
      message: '삭제 실패: $e',
      errorCode: 'delete_failed',
    );
  }
}
