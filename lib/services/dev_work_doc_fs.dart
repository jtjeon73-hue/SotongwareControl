/// FSA 디렉터리/파일 연산 계약 (테스트용 모의 가능).
library;

/// 브라우저 File System Access API와 동일한 create 동작 계약.
abstract class DevWorkDocFsAdapter {
  Future<void> ensureDir(List<String> segments, {required bool create});

  Future<bool> dirExists(List<String> segments);

  Future<void> writeFile(
    List<String> dirSegments,
    String fileName,
    String content,
  );

  Future<({String? text, int size})> readFile(
    List<String> dirSegments,
    String fileName,
  );

  Future<bool> fileExists(List<String> dirSegments, String fileName);
}

/// create:false 시 없는 경로는 null/false, create:true 시 생성.
class MemoryDevWorkDocFs implements DevWorkDocFsAdapter {
  final Map<String, String> files = {};
  final Set<String> dirs = {'/'};

  String _dirKey(List<String> segments) {
    if (segments.isEmpty) return '/';
    return '/${segments.join('/')}/';
  }

  String _fileKey(List<String> dirSegments, String fileName) =>
      '${_dirKey(dirSegments)}$fileName';

  @override
  Future<bool> dirExists(List<String> segments) async {
    return dirs.contains(_dirKey(segments));
  }

  @override
  Future<void> ensureDir(List<String> segments, {required bool create}) async {
    if (segments.isEmpty) return;
    final built = <String>[];
    for (final part in segments) {
      if (part.isEmpty) {
        throw StateError('empty path segment');
      }
      built.add(part);
      final key = _dirKey(built);
      if (!dirs.contains(key)) {
        if (!create) {
          throw FsNotFoundException(
            step: 'getDirectoryHandle',
            relativePath: built.join('/'),
            message: 'Directory not found (create:false)',
          );
        }
        dirs.add(key);
      }
    }
  }

  @override
  Future<bool> fileExists(List<String> dirSegments, String fileName) async {
    return files.containsKey(_fileKey(dirSegments, fileName));
  }

  @override
  Future<void> writeFile(
    List<String> dirSegments,
    String fileName,
    String content,
  ) async {
    await ensureDir(dirSegments, create: true);
    files[_fileKey(dirSegments, fileName)] = content;
  }

  @override
  Future<({String? text, int size})> readFile(
    List<String> dirSegments,
    String fileName,
  ) async {
    try {
      await ensureDir(dirSegments, create: false);
    } on FsNotFoundException {
      return (text: null, size: 0);
    }
    final text = files[_fileKey(dirSegments, fileName)];
    if (text == null) return (text: null, size: 0);
    return (text: text, size: text.length);
  }
}

class FsNotFoundException implements Exception {
  FsNotFoundException({
    required this.step,
    required this.relativePath,
    required this.message,
  });

  final String step;
  final String relativePath;
  final String message;

  @override
  String toString() => 'NotFoundError@$step:$relativePath $message';
}

/// 저장 단계 추적.
class DevWorkDocSaveStep {
  static const root = 'root_handle';
  static const artifactDir = 'artifact_directory';
  static const versionsDir = 'versions_directory';
  static const instructionDir = 'instructionId_directory';
  static const versionFileCreate = 'version_file_create';
  static const versionFileWrite = 'version_file_write';
  static const versionFileReread = 'version_file_reread';
  static const activeDir = 'active_directory';
  static const activeFileCreate = 'active_file_create';
  static const activeFileWrite = 'active_file_write';
  static const activeFileReread = 'active_file_reread';
  static const checksum = 'checksum_verify';
  static const existsProbe = 'exists_probe';
}

class DevWorkDocStepError implements Exception {
  DevWorkDocStepError({
    required this.step,
    required this.relativePath,
    required this.domName,
    required this.message,
  });

  final String step;
  final String relativePath;
  final String domName;
  final String message;

  String get userMessage =>
      '실패 단계: $step\n대상: $relativePath\n오류: $domName\n$message';

  @override
  String toString() => userMessage;
}
